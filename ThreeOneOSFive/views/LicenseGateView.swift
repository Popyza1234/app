import SwiftUI
import UIKit

/// Lock screen shown until a valid key is bound to this device.
///
/// The card explains exactly what is wrong (unknown key, key used on another
/// phone, revoked, expired) instead of a generic failure, so support questions
/// answer themselves.
struct LicenseGateView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var license = LicenseManager.shared

    @State private var keyInput = ""
    @State private var message: String?
    @State private var screenWidth = DekpopLayout.defaultWidth

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                keyCard
                if let message {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if showsGuide {
                    stepsCard
                }
                hintCard
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .dekpopContentWidth(inset: DekpopLayout.inset(for: screenWidth))
            .padding(.top, 22)
            .padding(.bottom, 40)
        }
        .dekpopMeasureWidth { screenWidth = $0 }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if keyInput.isEmpty, !license.storedKey.isEmpty {
                keyInput = license.storedKey
            }
        }
    }

    /// The guide is pointless once a key is already stored and only failing
    /// validation, so it only appears before the first activation.
    private var showsGuide: Bool {
        license.storedKey.isEmpty && !license.isBusy
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 20, x: 0, y: 12)

                Image(systemName: "key.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            Text(language.text("license.title"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(language.text("license.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var keyCard: some View {
        DekpopGlassCard(padding: 16, cornerRadius: DekpopRadius.medium) {
            VStack(alignment: .leading, spacing: 12) {
                Text(language.text("license.key_label"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(language.text("license.key_placeholder"), text: $keyInput)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { submit() }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                    )

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if license.isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "lock.open.fill")
                        }
                        Text(license.isBusy ? language.text("license.activating") : language.text("license.activate"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DekpopGradientButtonStyle())
                .disabled(license.isBusy)

                statusLine

                if !license.storedKey.isEmpty {
                    Button {
                        Task { await license.refresh() }
                    } label: {
                        Label(language.text("license.retry"), systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(license.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch license.status {
        case .checking:
            Label(language.text("license.activating"), systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)

        case .active(let expiresAt), .offlineGrace(let expiresAt):
            Label(expiresText(expiresAt), systemImage: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)

        case .blocked(let reason):
            Label(reasonText(reason), systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

        case .locked:
            EmptyView()
        }
    }

    private var stepsCard: some View {
        DekpopGlassCard(padding: 16, cornerRadius: DekpopRadius.medium) {
            VStack(alignment: .leading, spacing: 12) {
                Text(language.text("license.steps_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                stepRow(1, language.text("license.step1"))
                stepRow(2, language.text("license.step2"))
                stepRow(3, language.text("license.step3"))
            }
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.accent.opacity(0.15)))

            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hintCard: some View {
        VStack(spacing: 6) {
            Text(language.text("license.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(language.text("license.device_label")) \(shortDeviceId)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func submit() {
        guard !license.isBusy else { return }
        message = nil
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            message = language.text("license.err_empty")
            return
        }

        Task {
            let ok = await license.activate(with: key)
            if ok {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                keyInput = license.storedKey
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                if license.lastFailure == .unknown {
                    message = language.text("license.err_network")
                }
            }
        }
    }

    private var shortDeviceId: String {
        let id = license.deviceId
        return id.count > 14 ? String(id.suffix(12)) : id
    }

    private func expiresText(_ date: Date?) -> String {
        guard let date else { return language.text("license.status_active") }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return language.text("license.status_active_until", formatter.string(from: date))
    }

    private func reasonText(_ reason: LicenseManager.Reason) -> String {
        switch reason {
        case .keyNotFound: return language.text("license.err_key_not_found")
        case .deviceMismatch: return language.text("license.err_device_mismatch")
        case .revoked: return language.text("license.err_revoked")
        case .expired: return language.text("license.err_expired")
        case .notActivated: return language.text("license.err_not_activated")
        case .invalidKey: return language.text("license.err_invalid")
        case .unknown: return language.text("license.err_network")
        }
    }
}
