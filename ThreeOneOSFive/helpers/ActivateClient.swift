import Foundation

/// Credentials pulled out of the guest JSON a customer pastes in.
struct GuestCredentials: Equatable {
    let uid: String
    let password: String
}

struct ActivateReply: Decodable {
    let status: String
    let message: String?
    let uid: String?

    init(status: String, message: String? = nil, uid: String? = nil) {
        self.status = status
        self.message = message
        self.uid = uid
    }
}

/// Failures surfaced to the UI. The view owns the localized wording so the
/// service layer stays free of presentation strings.
enum ActivateFailure: Error {
    case invalidJSON
    case missingCredentials
    case offline
    case transport
    /// The provider answered with `status != "success"` (or a non-2xx code).
    case server(String)

    var serverMessage: String? {
        if case .server(let message) = self, !message.isEmpty { return message }
        return nil
    }
}

/// Talks to dekpop's own activation API. The Worker binds the UID to this
/// phone's device id, its licence key and the request IP, and stamps an expiry
/// that follows the licence — no third-party box is involved.
struct ActivateClient {
    static let shared = ActivateClient()

    /// The licence server doubles as the activation service.
    let apiRoot = "https://site-9d840023b7f443be923d5bdb73ae9d13.freebuff.page"

    /// Legacy value from the third-party flow. Activation no longer uses an
    /// HTTP proxy, and nothing in the UI shows this any more.
    let proxyAddress = "82.26.104.242:8080"

    private let requestTimeout: TimeInterval = 20

    var proxyHost: String {
        proxyAddress.split(separator: ":").first.map(String.init) ?? proxyAddress
    }

    var proxyPort: Int {
        proxyAddress.split(separator: ":").last.flatMap { Int($0) } ?? 8080
    }

    func activate(rawJSON: String) async throws -> ActivateReply {
        let credentials = try Self.parse(rawJSON)
        let trimmed = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let body = trimmed.data(using: .utf8) else { throw ActivateFailure.invalidJSON }

        let reply = try await send(path: "/api/activate", body: body)
        guard reply.status.lowercased() == "success" else {
            throw ActivateFailure.server(reply.message ?? "")
        }
        return ActivateReply(status: reply.status, message: reply.message, uid: reply.uid ?? credentials.uid)
    }

    func deactivate() async throws -> ActivateReply {
        let reply = try await send(path: "/api/deactivate", body: nil)
        guard reply.status.lowercased() == "success" else {
            throw ActivateFailure.server(reply.message ?? "")
        }
        return reply
    }

    // MARK: - JSON helpers

    static func parse(_ rawJSON: String) throws -> GuestCredentials {
        let trimmed = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            throw ActivateFailure.invalidJSON
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ActivateFailure.invalidJSON
        }

        let box = (root["guest_account_info"] as? [String: Any]) ?? root
        var uid: String?
        var password = ""

        for (key, value) in box {
            let lowered = key.lowercased()
            if uid == nil, lowered.hasSuffix("guest_uid") || lowered == "uid" || lowered == "guestuid" {
                uid = stringValue(value)
            }
            if password.isEmpty, lowered.hasSuffix("guest_password") || lowered == "password" || lowered == "pass" {
                password = stringValue(value) ?? ""
            }
        }

        guard let uid, !uid.isEmpty else { throw ActivateFailure.missingCredentials }
        return GuestCredentials(uid: uid, password: password)
    }

    /// Re-indents the pasted JSON so the customer can sanity-check it.
    static func prettify(_ rawJSON: String) -> String? {
        guard let data = rawJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ),
              let text = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return text
    }

    /// A short, human-readable UID preview for the history list.
    static func shortUID(_ uid: String) -> String {
        guard uid.count > 9 else { return uid }
        return uid.prefix(4) + "…" + uid.suffix(4)
    }

    private static func stringValue(_ value: Any) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    // MARK: - Transport

    /// One retry on transport failures; a server-side rejection is never retried.
    private func send(path: String, body: Data?) async throws -> ActivateReply {
        guard let url = URL(string: apiRoot + path) else { throw ActivateFailure.transport }

        var lastFailure: ActivateFailure = .transport

        for attempt in 0..<2 {
            do {
                return try await sendOnce(url: url, body: body)
            } catch let failure as ActivateFailure {
                lastFailure = failure
                if case .server = failure { throw failure }
                if case .missingCredentials = failure { throw failure }
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            } catch {
                lastFailure = .transport
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            }
        }

        throw lastFailure
    }

    private func sendOnce(url: URL, body: Data?) async throws -> ActivateReply {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // The licence key is the authorisation for an activation; the device id
        // keeps a copied key from activating on a second phone.
        let licence = LicenseManager.shared
        if !licence.storedKey.isEmpty {
            request.setValue(licence.storedKey, forHTTPHeaderField: "x-license-key")
        }
        request.setValue(licence.deviceId, forHTTPHeaderField: "x-device-id")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let decoded = try? JSONDecoder().decode(ActivateReply.self, from: data)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ActivateFailure.server(decoded?.message ?? "HTTP \(http.statusCode)")
            }
            guard let decoded else { throw ActivateFailure.transport }
            return decoded
        } catch let failure as ActivateFailure {
            throw failure
        } catch let urlError as URLError {
            throw urlError.code == .notConnectedToInternet ? ActivateFailure.offline : ActivateFailure.transport
        } catch {
            throw ActivateFailure.transport
        }
    }
}

/// Remembers the last successful activation so the screen still shows it after
/// the app is relaunched. Purely local — nothing is uploaded anywhere.
enum ActivationMemory {
    private static let uidKey = "activate.lastUID"
    private static let dateKey = "activate.lastDate"
    private static let historyKey = "activate.history"

    static var lastUID: String? {
        let value = UserDefaults.standard.string(forKey: uidKey)
        return (value?.isEmpty == false) ? value : nil
    }

    static var lastDate: Date? {
        let stamp = UserDefaults.standard.double(forKey: dateKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    static var history: [String] {
        UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    static func remember(uid: String) {
        let defaults = UserDefaults.standard
        defaults.set(uid, forKey: uidKey)
        defaults.set(Date().timeIntervalSince1970, forKey: dateKey)

        var items = defaults.stringArray(forKey: historyKey) ?? []
        items.removeAll { $0 == uid }
        items.insert(uid, at: 0)
        defaults.set(Array(items.prefix(6)), forKey: historyKey)
    }

    static func forgetCurrent() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: uidKey)
        defaults.removeObject(forKey: dateKey)
    }

    static func clearHistory() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: historyKey)
        forgetCurrent()
    }
}
