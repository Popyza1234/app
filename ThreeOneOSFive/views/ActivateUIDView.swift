import SwiftUI
import UIKit

/// Guest UID activation screen ("ลงไก่").
///
/// The provider's API is called straight from the device, so the UID is bound
/// to the phone's own IP address — no backend of ours is involved. Network,
/// JSON and persistence work lives in `ActivateClient`.
struct ActivateUIDView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var jsonText = ""
    @State private var phase: Phase = .ready
    @State private var detail = ""
    @State private var activeUID = ""
    @State private var activatedAt: Date?
    @State private var copied: CopiedTarget?
    @State private var pulse = false
    @State private var showingSetup = false
    @State private var screenWidth = DekpopLayout.defaultWidth

    private let client = ActivateClient.shared

    enum Phase: Equatable {
        case ready
        case working
        case active
        case failed
    }

    private enum CopiedTarget: Equatable {
        case proxy
        case uid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DekpopAuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        editorCard
                        actionRow
                        resultCard
                        proxyCard
                        if !ActivationMemory.history.isEmpty {
                            historyCard
                        }
                        stepsCard

                        Text(language.text("activate.footer"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                    }
                    .dekpopContentWidth(inset: DekpopLayout.inset(for: screenWidth))
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .dekpopMeasureWidth { screenWidth = $0 }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(language.text("activate.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.close")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .tint(AppTheme.accent)
        .onAppear(perform: restoreLastActivation)
        .sheet(isPresented: $showingSetup) {
            DeviceProxySetupView()
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulse && phase == .working ? 1.10 : 1)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: pulse
                    )

                Text(language.text("activate.heading"))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

            Text(language.text("activate.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Editor

    private var editorCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(language.text("activate.input_label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label(language.text("activate.paste"), systemImage: "doc.on.clipboard")
                        }
                        Button {
                            formatJSON()
                        } label: {
                            Label(language.text("activate.format"), systemImage: "text.alignleft")
                        }
                        Button(role: .destructive) {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                jsonText = ""
                            }
                        } label: {
                            Label(language.text("activate.clear"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(language.text("activate.input_label"))
                }

                ZStack(alignment: .topLeading) {
                    if jsonText.isEmpty {
                        Text(language.text("activate.placeholder"))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $jsonText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 170)
                        .padding(4)
                        .scrollContentBackground(.hidden)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.tertiarySystemFill).opacity(colorScheme == .dark ? 0.55 : 0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 0.8)
                )
            }
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await activate() }
            } label: {
                HStack(spacing: 8) {
                    if phase == .working {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(language.text("activate.activate"))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: .purple.opacity(0.35), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(DekpopPressStyle())
            .disabled(!canActivate)
            .opacity(canActivate ? 1 : 0.5)

            Button {
                Task { await deactivate() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                    Text(language.text("activate.deactivate"))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5), lineWidth: 0.8)
                )
            }
            .buttonStyle(DekpopPressStyle())
            .disabled(!canDeactivate)
            .opacity(canDeactivate ? 1 : 0.5)
        }
    }

    // MARK: - Result

    private var resultCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(language.text("activate.result_title"))
                        .font(.headline)
                    Spacer()
                    statusBadge
                }

                VStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(statusTint)
                        .symbolRenderingMode(.hierarchical)
                        .transition(.scale.combined(with: .opacity))

                    Text(statusTitle)
                        .font(.headline)

                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemFill).opacity(colorScheme == .dark ? 0.5 : 0.65))
                )
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: phase)

                if !activeUID.isEmpty {
                    VStack(spacing: 0) {
                        detailRow(
                            title: language.text("activate.uid_label"),
                            value: activeUID,
                            copyTarget: .uid
                        )
                        if let activatedAt {
                            Divider().opacity(0.4)
                            detailRow(
                                title: language.text("activate.started"),
                                value: Self.timeFormatter.string(from: activatedAt),
                                copyTarget: nil
                            )
                        }
                        Divider().opacity(0.4)
                        detailRow(
                            title: language.text("activate.proxy_label"),
                            value: client.proxyAddress,
                            copyTarget: .proxy
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemFill).opacity(0.5))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func detailRow(title: String, value: String, copyTarget: CopiedTarget?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            if let copyTarget {
                Button {
                    copy(value, target: copyTarget)
                } label: {
                    Image(systemName: copied == copyTarget ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(copied == copyTarget ? .green : AppTheme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Proxy

    private var proxyCard: some View {
        glassCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(language.text("activate.proxy_label"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(client.proxyAddress)
                        .font(.system(.footnote, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                }

                Spacer(minLength: 6)

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .padding(9)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel(language.text("activate.share"))

                Button {
                    copy(client.proxyAddress, target: .proxy)
                } label: {
                    Label(
                        copied == .proxy
                            ? language.text("activate.copied")
                            : language.text("activate.copy"),
                        systemImage: copied == .proxy ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .buttonStyle(DekpopPressStyle())
            }
        }
    }

    // MARK: - History & steps

    private var historyCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(language.text("activate.history"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(language.text("activate.history_clear")) {
                        ActivationMemory.clearHistory()
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            activeUID = ""
                            activatedAt = nil
                            phase = .ready
                            detail = ""
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivationMemory.history, id: \.self) { uid in
                            Button {
                                UIPasteboard.general.string = uid
                                haptic(.success)
                            } label: {
                                Text(ActivateClient.shortUID(uid))
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var stepsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(language.text("activate.steps_title"))
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Button { showingSetup = true } label: {
                        Label(language.text("setup.open"), systemImage: "gearshape")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                }

                ForEach(1...4, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.purple.opacity(0.75)))

                        Text(language.text("activate.step_\(index)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func glassCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        DekpopGlassCard(padding: 15, cornerRadius: DekpopRadius.medium) {
            content()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    private var shareText: String {
        var lines = ["dekpop · Activate UID", "Proxy: \(client.proxyAddress)"]
        if !activeUID.isEmpty { lines.append("UID: \(activeUID)") }
        return lines.joined(separator: "\n")
    }

    private var canActivate: Bool {
        phase != .working && !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canDeactivate: Bool {
        phase != .working && (!activeUID.isEmpty || !jsonText.isEmpty)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(statusTitle)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: phase)
    }

    private var statusTitle: String {
        switch phase {
        case .ready: return language.text("activate.ready_title")
        case .working: return language.text("activate.working_title")
        case .active: return language.text("activate.active_title")
        case .failed: return language.text("activate.failed_title")
        }
    }

    private var statusMessage: String {
        if !detail.isEmpty { return detail }
        switch phase {
        case .ready: return language.text("activate.ready_detail")
        case .working: return language.text("activate.working_detail")
        case .active: return language.text("activate.active_detail")
        case .failed: return language.text("activate.error_generic")
        }
    }

    private var statusIcon: String {
        switch phase {
        case .ready: return "sparkles"
        case .working: return "arrow.triangle.2.circlepath"
        case .active: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusTint: Color {
        switch phase {
        case .ready: return Color.secondary
        case .working: return AppTheme.accent
        case .active: return .green
        case .failed: return .red
        }
    }

    // MARK: - Actions

    private func activate() async {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await setPhase(.failed, message: language.text("activate.error_empty"))
            return
        }

        await setPhase(.working, message: language.text("activate.working_detail"))

        do {
            let reply = try await client.activate(rawJSON: trimmed)
            let uid = reply.uid ?? ""

            await MainActor.run {
                activeUID = uid
                activatedAt = Date()
                detail = language.text("activate.active_detail")
                phase = .active
                jsonText = ""
                ActivationMemory.remember(uid: uid)
                haptic(.success)
            }
        } catch {
            await setPhase(.failed, message: message(for: error))
            await MainActor.run { haptic(.error) }
        }
    }

    private func deactivate() async {
        await setPhase(.working, message: language.text("activate.deactivate_detail"))

        do {
            _ = try await client.deactivate()
            await MainActor.run {
                ActivationMemory.forgetCurrent()
                activeUID = ""
                activatedAt = nil
                detail = ""
                phase = .ready
                haptic(.success)
            }
        } catch {
            await setPhase(.failed, message: message(for: error))
            await MainActor.run { haptic(.error) }
        }
    }

    private func pasteFromClipboard() {
        guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else {
            Task { await setPhase(.failed, message: language.text("activate.error_clipboard")) }
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            jsonText = clipboard
        }
        haptic(.success)
    }

    private func formatJSON() {
        guard let pretty = ActivateClient.prettify(jsonText) else {
            Task { await setPhase(.failed, message: language.text("activate.error_json")) }
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            jsonText = pretty
        }
        haptic(.success)
    }

    private func copy(_ value: String, target: CopiedTarget) {
        UIPasteboard.general.string = value
        haptic(.success)
        withAnimation(.easeOut(duration: 0.2)) { copied = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copied == target {
                withAnimation(.easeOut(duration: 0.2)) { copied = nil }
            }
        }
    }

    private func restoreLastActivation() {
        pulse = true
        guard let uid = ActivationMemory.lastUID else { return }
        activeUID = uid
        activatedAt = ActivationMemory.lastDate
        phase = .active
        detail = language.text("activate.active_detail")
    }

    private func message(for error: Error) -> String {
        guard let failure = error as? ActivateFailure else {
            return language.text("activate.error_transport")
        }
        switch failure {
        case .invalidJSON:
            return language.text("activate.error_json")
        case .missingCredentials:
            return language.text("activate.error_missing")
        case .offline:
            return language.text("activate.error_offline")
        case .transport:
            return language.text("activate.error_transport")
        case .server(let message):
            return message.isEmpty ? language.text("activate.error_generic") : message
        }
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    @MainActor
    private func setPhase(_ newPhase: Phase, message: String) {
        phase = newPhase
        detail = message
    }
}
