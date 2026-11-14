import Foundation
import Security
import UIKit

/// Key-based licensing: one key unlocks exactly one device.
///
/// The key and the device id live in the keychain, so reinstalling the app does
/// not burn a second activation — only a different device does. The server is
/// the authority; a short offline window keeps a paying customer working when
/// the network is down, but only within the period that was already verified.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    static let serverRoot = URL(string: "https://site-9d840023b7f443be923d5bdb73ae9d13.freebuff.page")!

    enum Status: Equatable {
        case checking
        case locked
        case active(expiresAt: Date?)
        case offlineGrace(expiresAt: Date?)
        case blocked(Reason)

        var isUnlocked: Bool {
            switch self {
            case .active, .offlineGrace: return true
            case .checking, .locked, .blocked: return false
            }
        }
    }

    enum Reason: String {
        case keyNotFound = "key_not_found"
        case deviceMismatch = "device_mismatch"
        case revoked = "key_revoked"
        case expired = "key_expired"
        case notActivated = "not_activated"
        case invalidKey = "invalid_key"
        case unknown = "unknown"
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var isBusy = false
    @Published private(set) var lastFailure: Reason?

    /// How long a verified licence keeps working without reaching the server.
    private let offlineWindow: TimeInterval = 7 * 24 * 3600

    private let defaults = UserDefaults.standard
    private let keyAccount = "dekpop.license.key"
    private let deviceAccount = "dekpop.device.id"
    private let lastValidStamp = "dekpop.license.lastValid"
    private let expiresStamp = "dekpop.license.expiresAt"

    private init() {}

    // MARK: - Public state

    var storedKey: String {
        Keychain.string(for: keyAccount) ?? ""
    }

    var isLicensed: Bool { status.isUnlocked }

    /// Stable per-install identity kept in the keychain. Survives app reinstall.
    var deviceId: String {
        if let existing = Keychain.string(for: deviceAccount), existing.count >= 8 {
            return existing
        }
        let generated = "ios-" + UUID().uuidString
        Keychain.set(generated, for: deviceAccount)
        return generated
    }

    var deviceName: String {
        let machine = UIDevice.current.model.isEmpty ? "iPhone" : UIDevice.current.model
        return "\(machine) · iOS \(UIDevice.current.systemVersion)"
    }

    // MARK: - Lifecycle

    /// Called on launch. Without a stored key the app stays locked.
    func start() async {
        guard !storedKey.isEmpty else {
            status = .locked
            return
        }
        // Open with the entitlement already verified on this device instead of
        // waiting for the network. A 15 second server timeout used to hold the
        // gate (and the whole browser) closed on a slow connection.
        if let cached = cachedStatus() {
            status = cached
        }
        await refresh()
    }

    func activate(with rawKey: String) async -> Bool {
        let key = Self.normalize(rawKey)
        guard key.count >= 8 else {
            lastFailure = .invalidKey
            return false
        }

        isBusy = true
        defer { isBusy = false }

        let result = await post(
            path: "/api/license/activate",
            body: ["key": key, "deviceId": deviceId, "deviceName": deviceName]
        )

        switch result {
        case .success(let payload):
            Keychain.set(Self.display(key), for: keyAccount)
            rememberSuccess(expiresAt: payload.expiresAt)
            lastFailure = nil
            status = .active(expiresAt: payload.expiresAt)
            return true

        case .failure(let reason):
            lastFailure = reason
            if reason != .unknown {
                status = .blocked(reason)
            }
            return false

        case .unreachable:
            lastFailure = .unknown
            return false
        }
    }

    func refresh() async {
        guard !storedKey.isEmpty else {
            status = .locked
            return
        }

        isBusy = true
        defer { isBusy = false }

        let result = await post(
            path: "/api/license/validate",
            body: ["key": Self.normalize(storedKey), "deviceId": deviceId]
        )

        switch result {
        case .success(let payload):
            rememberSuccess(expiresAt: payload.expiresAt)
            lastFailure = nil
            status = .active(expiresAt: payload.expiresAt)

        case .failure(let reason):
            lastFailure = reason
            status = .blocked(reason)

        case .unreachable:
            if let cached = cachedStatus() {
                status = cached
            } else {
                lastFailure = .unknown
                status = .blocked(.unknown)
            }
        }
    }

    func signOut() {
        Keychain.delete(keyAccount)
        defaults.removeObject(forKey: lastValidStamp)
        defaults.removeObject(forKey: expiresStamp)
        status = .locked
    }

    // MARK: - Cache

    private func rememberSuccess(expiresAt: Date?) {
        defaults.set(Date().timeIntervalSince1970, forKey: lastValidStamp)
        if let expiresAt {
            defaults.set(expiresAt.timeIntervalSince1970, forKey: expiresStamp)
        }
    }

    private func cachedStatus() -> Status? {
        let stamp = defaults.double(forKey: lastValidStamp)
        guard stamp > 0 else { return nil }
        let verified = Date(timeIntervalSince1970: stamp)
        guard Date().timeIntervalSince(verified) < offlineWindow else { return nil }

        let expires = defaults.double(forKey: expiresStamp)
        let expiresAt = expires > 0 ? Date(timeIntervalSince1970: expires) : nil
        if let expiresAt, expiresAt < Date() { return .blocked(.expired) }
        return .offlineGrace(expiresAt: expiresAt)
    }

    // MARK: - Networking

    private enum Outcome {
        case success(Payload)
        case failure(Reason)
        case unreachable
    }

    private struct Payload {
        let expiresAt: Date?
    }

    private func post(path: String, body: [String: String]) async -> Outcome {
        var request = URLRequest(url: Self.serverRoot.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("dekpop-ios", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unreachable }

            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let ok = (object["ok"] as? Bool) ?? false

            if ok {
                let stamp = (object["expiresAt"] as? Double) ?? Double(object["expiresAt"] as? Int ?? 0)
                let expiresAt = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
                return .success(Payload(expiresAt: expiresAt))
            }

            let error = (object["error"] as? String) ?? ""
            return .failure(Reason(rawValue: error) ?? (http.statusCode == 401 ? .unknown : .unknown))
        } catch {
            return .unreachable
        }
    }

    // MARK: - Key format

    static func normalize(_ value: String) -> String {
        let cleaned = value.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !cleaned.isEmpty else { return "" }
        if cleaned.hasPrefix("DKP") { return cleaned }
        return "DKP" + cleaned
    }

    static func display(_ normalized: String) -> String {
        let body = normalized.hasPrefix("DKP") ? String(normalized.dropFirst(3)) : normalized
        var groups: [String] = []
        var index = body.startIndex
        while index < body.endIndex {
            let end = body.index(index, offsetBy: 4, limitedBy: body.endIndex) ?? body.endIndex
            groups.append(String(body[index..<end]))
            index = end
        }
        return "DKP-" + groups.joined(separator: "-")
    }
}

// MARK: - Keychain

enum Keychain {
    private static let service = "com.dekpop.license"

    static func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
