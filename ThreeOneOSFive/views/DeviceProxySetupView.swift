import SwiftUI
import UIKit
import CFNetwork

/// On-device proxy setup, so no separate proxy/VPN app is required.
///
/// iOS can send Wi-Fi traffic through an HTTP proxy from the system settings.
/// This screen shows the exact values, checks whether the device is already
/// pointed at our proxy, and walks through installing the mitmproxy CA.
struct DeviceProxySetupView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var copied: String?
    @State private var detected: DetectedProxy?
    @State private var didCheck = false
    @State private var profileURL: URL?
    @State private var certificateFailed = false
    @State private var installFailed = false
    @State private var routeResult: ProxyRouteCheck.Result?
    @State private var isTestingRoute = false

    private let client = ActivateClient.shared

    private struct DetectedProxy: Equatable {
        let host: String
        let port: Int
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DekpopAuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        statusCard
                        routeCard
                        valuesCard
                        certificateCard
                        stepsCard
                        noteCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(language.text("setup.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.close")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .tint(AppTheme.accent)
        .onAppear(perform: refreshProxy)
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wifi.router.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(language.text("setup.heading"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Spacer(minLength: 0)
            }

            Text(language.text("setup.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private var statusCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(language.text("setup.status_title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        refreshProxy()
                    } label: {
                        Label(language.text("setup.refresh"), systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                }

                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(.subheadline.weight(.semibold))

                        if let detail = statusDetail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var valuesCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(language.text("setup.values_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                valueRow(language.text("setup.server"), value: host, copyKey: "host")
                Divider().opacity(0.4)
                valueRow(language.text("setup.port"), value: portText, copyKey: "port")
                Divider().opacity(0.4)
                valueRow(language.text("setup.type"), value: "HTTP", copyKey: nil)
                Divider().opacity(0.4)
                valueRow(language.text("setup.auth"), value: language.text("setup.none"), copyKey: nil)

                Button {
                    copy("\(host):\(portText)", target: "all")
                } label: {
                    Label(
                        copied == "all"
                            ? language.text("setup.copied")
                            : language.text("setup.copy_all"),
                        systemImage: copied == "all" ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(DekpopPressStyle())
                .padding(.top, 12)
            }
        }
    }

    private var routeCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("setup.route_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(language.text("setup.route_body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    runRouteCheck()
                } label: {
                    HStack(spacing: 8) {
                        if isTestingRoute {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(isTestingRoute ? language.text("setup.route_testing") : language.text("setup.route_button"))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(DekpopPressStyle())
                .disabled(isTestingRoute)

                if let routeResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(routeTitle(routeResult), systemImage: routeSymbol(routeResult))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(routeColor(routeResult))

                        if let detail = routeDetail(routeResult) {
                            Text(detail)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var certificateCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("setup.cert_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(language.text("setup.cert_body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    installProfileDirectly()
                } label: {
                    Label(language.text("setup.cert_install"), systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(DekpopPressStyle())

                Text(language.text("setup.cert_install_hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if installFailed {
                    Label(language.text("setup.cert_install_error"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(language.text("setup.cert_file_option"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Button {
                    createCertificateProfile()
                } label: {
                    Label(language.text("setup.cert_button"), systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )

                if certificateFailed {
                    Label(language.text("setup.cert_error"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if let profileURL {
                    Text(language.text("setup.cert_ready"))
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)

                    ShareLink(item: profileURL) {
                        Label(language.text("setup.cert_share"), systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )
                }

                Text(language.text("setup.cert_trust"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stepsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(language.text("setup.steps_title"))
                    .font(.subheadline.weight(.semibold))

                ForEach(1...5, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.purple.opacity(0.75)))

                        Text(language.text("setup.step_\(index)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    openSettingsApp()
                } label: {
                    Label(language.text("setup.open_settings"), systemImage: "gearshape")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                .padding(.top, 4)
            }
        }
    }

    private var noteCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label(language.text("setup.note_title"), systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(language.text("setup.note_body"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func valueRow(_ title: String, value: String, copyKey: String?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)

            if let copyKey {
                Button {
                    copy(value, target: copyKey)
                } label: {
                    Image(systemName: copied == copyKey ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(copied == copyKey ? .green : AppTheme.accent)
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: - Helpers

    private var host: String {
        client.proxyAddress.split(separator: ":").first.map(String.init) ?? client.proxyAddress
    }

    private var portText: String {
        client.proxyAddress.split(separator: ":").last.map(String.init) ?? "8080"
    }

    private var expectedPort: Int {
        Int(portText) ?? 8080
    }

    private var isMatched: Bool {
        guard let detected else { return false }
        return detected.host == host && detected.port == expectedPort
    }

    private var statusColor: Color {
        guard didCheck else { return .gray }
        guard let detected else { return .orange }
        return isMatched ? .green : .orange
    }

    private var statusTitle: String {
        guard didCheck else { return language.text("setup.status_unknown") }
        guard let detected else { return language.text("setup.status_none") }
        return isMatched ? language.text("setup.status_matched") : language.text("setup.status_other")
    }

    private var statusDetail: String? {
        guard didCheck else { return nil }
        guard let detected else { return language.text("setup.status_none_detail") }
        return "\(detected.host):\(detected.port)"
    }

    private func glassCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        DekpopGlassCard(padding: 15, cornerRadius: DekpopRadius.medium) {
            content()
        }
    }

    private func copy(_ value: String, target: String) {
        UIPasteboard.general.string = value
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.easeOut(duration: 0.2)) { copied = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copied == target {
                withAnimation(.easeOut(duration: 0.2)) { copied = nil }
            }
        }
    }

    private func runRouteCheck() {
        guard !isTestingRoute else { return }
        isTestingRoute = true
        routeResult = nil

        Task {
            let result = await ProxyRouteCheck.run(expectedProxyHost: host)
            await MainActor.run {
                routeResult = result
                isTestingRoute = false
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(routeSucceeded(result) ? .success : .warning)
            }
        }
    }

    private func routeSucceeded(_ result: ProxyRouteCheck.Result) -> Bool {
        if case .throughProxy = result { return true }
        return false
    }

    private func routeTitle(_ result: ProxyRouteCheck.Result) -> String {
        switch result {
        case .throughProxy:
            return language.text("setup.route_ok")
        case .direct:
            return language.text("setup.route_direct")
        case .failed:
            return language.text("setup.route_fail")
        }
    }

    private func routeSymbol(_ result: ProxyRouteCheck.Result) -> String {
        switch result {
        case .throughProxy:
            return "checkmark.shield.fill"
        case .direct:
            return "exclamationmark.shield.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private func routeColor(_ result: ProxyRouteCheck.Result) -> Color {
        switch result {
        case .throughProxy:
            return .green
        case .direct:
            return .orange
        case .failed:
            return .red
        }
    }

    private func routeDetail(_ result: ProxyRouteCheck.Result) -> String? {
        switch result {
        case let .throughProxy(ip, milliseconds), let .direct(ip, milliseconds):
            return "IP \(ip) · \(milliseconds) ms"
        case let .failed(reason):
            return reason
        }
    }

    /// Hands the profile to iOS without any download: a loopback server serves
    /// it, Safari picks it up, and Settings shows the install sheet.
    private func installProfileDirectly() {
        do {
            let data = try CertificateInstaller.makeProfile()
            installFailed = false

            Task {
                do {
                    let url = try await LocalProfileServer.shared.start(
                        data: data,
                        fileName: CertificateInstaller.profileFileName
                    )
                    await MainActor.run {
                        UIApplication.shared.open(url)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } catch {
                    LocalProfileServer.shared.stop()
                    await MainActor.run { installFailed = true }
                }
            }
        } catch {
            installFailed = true
        }
    }

    private func createCertificateProfile() {
        do {
            profileURL = try CertificateInstaller.writeProfileToDocuments()
            certificateFailed = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            profileURL = nil
            certificateFailed = true
        }
    }

    private func openSettingsApp() {
        for candidate in ["App-Prefs:root=WIFI", UIApplication.openSettingsURLString] {
            guard let url = URL(string: candidate) else { continue }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }

    /// Reads the proxy the system is currently configured to use.
    private func refreshProxy() {
        detected = Self.readSystemProxy()
        didCheck = true

        // Keep the profile in Documents so it is always findable in the Files
        // app, without the user having to ask for it first.
        if profileURL == nil {
            profileURL = try? CertificateInstaller.writeProfileToDocuments()
        }
    }

    private static func readSystemProxy() -> DetectedProxy? {
        guard let raw = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = raw as? [String: Any] else {
            return nil
        }

        func flag(_ key: String) -> Bool {
            (settings[key] as? NSNumber)?.boolValue ?? false
        }
        func text(_ key: String) -> String? {
            if let value = settings[key] as? String, !value.isEmpty { return value }
            return nil
        }
        func number(_ key: String) -> Int? {
            if let value = settings[key] as? NSNumber { return value.intValue }
            if let value = settings[key] as? String { return Int(value) }
            return nil
        }

        // The kCFNetworkProxies… constants are macOS-only, but the dictionary
        // keys they stand for are the same on iOS, so spell them out here.
        let httpsHost = "HTTPSProxy"
        let httpsPort = "HTTPSPort"
        let httpsEnable = "HTTPSEnable"
        let httpHost = "HTTPProxy"
        let httpPort = "HTTPPort"
        let httpEnable = "HTTPEnable"

        if flag(httpsEnable), let host = text(httpsHost), let port = number(httpsPort) {
            return DetectedProxy(host: host, port: port)
        }
        if flag(httpEnable), let host = text(httpHost), let port = number(httpPort) {
            return DetectedProxy(host: host, port: port)
        }
        return nil
    }
}
