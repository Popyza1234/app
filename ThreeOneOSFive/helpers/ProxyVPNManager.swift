import Foundation
import NetworkExtension

/// Drives the bundled PacketTunnel extension.
///
/// The tunnel itself is a port of ProxyPin's iOS packet tunnel (Apache 2.0, see
/// PacketTunnel/LICENSE-ProxyPin.txt): it either hands the system an HTTP proxy
/// for all traffic, or, in IP mode, forwards raw packets to that proxy itself.
///
/// Starting a tunnel needs the `packet-tunnel-provider` entitlement in the
/// signing profile. With a plain sideload certificate the save/start calls fail
/// and the reason is surfaced instead of a silent no-op, so the UI can explain
/// what is missing.
@MainActor
final class ProxyVPNManager: ObservableObject {
    static let shared = ProxyVPNManager()

    enum State: Equatable {
        case off
        case connecting
        case on
        case disconnecting
        case unsupported(String)
    }

    @Published private(set) var state: State = .off
    @Published private(set) var isBusy = false

    private var manager: NETunnelProviderManager?

    private init() {}

    var isOn: Bool { state == .on }

    /// Re-reads the system state. Cheap enough to call on every appearance.
    func refresh() async {
        let managers = await loadManagers()
        guard let manager = managers.first else {
            state = .off
            return
        }
        self.manager = manager
        switch manager.connection.status {
        case .connected: state = .on
        case .connecting, .reasserting: state = .connecting
        case .disconnecting: state = .disconnecting
        default: state = .off
        }
    }

    func start(host: String, port: Int, ipMode: Bool, bypassDomains: [String] = []) async -> String? {
        isBusy = true
        defer { isBusy = false }

        do {
            let manager = try await configuredManager(host: host, port: port, ipMode: ipMode, bypassDomains: bypassDomains)
            self.manager = manager

            try manager.connection.startVPNTunnel()
            state = .connecting
            await waitForStatus(expected: .connected, timeout: 12)
            return nil
        } catch {
            let message = Self.describe(error)
            state = .unsupported(message)
            return message
        }
    }

    func stop() async {
        isBusy = true
        defer { isBusy = false }

        guard let manager = manager ?? (await loadManagers()).first else {
            state = .off
            return
        }
        manager.connection.stopVPNTunnel()
        state = .disconnecting
        await waitForStatus(expected: .disconnected, timeout: 8)
    }

    // MARK: - Preferences

    private func loadManagers() async -> [NETunnelProviderManager] {
        await withCheckedContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, _ in
                continuation.resume(returning: managers ?? [])
            }
        }
    }

    private func configuredManager(
        host: String,
        port: Int,
        ipMode: Bool,
        bypassDomains: [String]
    ) async throws -> NETunnelProviderManager {
        let manager = manager ?? (await loadManagers()).first ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = Self.providerBundleId
        proto.serverAddress = "\(host):\(port)"
        proto.providerConfiguration = [
            "proxyHost": host,
            "proxyPort": port,
            "ipProxy": ipMode,
            "proxyPassDomains": bypassDomains,
        ]

        manager.protocolConfiguration = proto
        manager.localizedDescription = "dekpop proxy"
        manager.isEnabled = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        // Reload: Apple requires the manager to be re-read before starting.
        let reloaded = await withCheckedContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, _ in
                continuation.resume(returning: managers?.first ?? manager)
            }
        }
        return reloaded
    }

    private func waitForStatus(expected: NEVPNStatus, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            await refresh()
            if state == .on, expected == .connected { return }
            if state == .off, expected == .disconnected { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: - Helpers

    private static var providerBundleId: String {
        let app = Bundle.main.bundleIdentifier ?? "com.apple.mobile.MobileHouseArrest"
        return app + ".tunnel"
    }

    /// Turns NEVPNError and CommonCrypto-free plist errors into something a
    /// human can act on.
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NEVPNErrorDomain {
            switch ns.code {
            case NEVPNError.configurationInvalid.rawValue:
                return "โปรไฟล์ VPN ไม่ถูกต้อง (configuration invalid)"
            case NEVPNError.configurationDisabled.rawValue:
                return "VPN ถูกปิดใน Settings"
            case NEVPNError.connectionFailed.rawValue:
                return "เริ่ม tunnel ไม่สำเร็จ (connection failed)"
            default:
                break
            }
        }
        if ns.localizedDescription.lowercased().contains("entitlement") {
            return "ลายเซ็นไม่มีสิทธิ์ Network Extension — ต้องเซ็นด้วย Apple Developer แบบเสียเงิน"
        }
        return ns.localizedDescription
    }
}
