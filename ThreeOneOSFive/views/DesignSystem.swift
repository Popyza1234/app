import SwiftUI
import UIKit

/// dekpop is a Files-only app. These constants are the single source of truth
/// for the product identity shown in the UI.
enum DekpopBrand {
    static let displayName = "dekpop"
    static let version = "1.5.0"
    static let build = "13"
}

enum AppTheme {
    /// Adaptive violet accent. Kept as a `Color` so every existing call site
    /// (`AppRowIcon`, tint, selection, buttons) keeps working unchanged.
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.70, green: 0.58, blue: 1.00, alpha: 1.00)
                : UIColor(red: 0.39, green: 0.24, blue: 0.90, alpha: 1.00)
        }
    )

    /// Hot-pink companion used for highlights and secondary icons.
    static let accentSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.57, blue: 0.76, alpha: 1.00)
                : UIColor(red: 0.93, green: 0.24, blue: 0.52, alpha: 1.00)
        }
    )

    static let brandStart = Color(red: 0.15, green: 0.09, blue: 0.42)
    static let brandMiddle = Color(red: 0.43, green: 0.25, blue: 0.94)
    static let brandEnd = Color(red: 0.98, green: 0.32, blue: 0.58)

    static let brandGradient = LinearGradient(
        colors: [brandStart, brandMiddle, brandEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

/// The dekpop wordmark: a gradient folder tile next to the lowercase name.
/// `compact` is used in the navigation bar; `onBrand` is used on top of a
/// gradient surface such as the hero card.
struct DekpopWordmark: View {
    var compact = false
    var onBrand = false

    private var tile: CGFloat { compact ? 24 : 30 }
    private var radius: CGFloat { compact ? 7 : 9 }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppTheme.brandGradient)
                if onBrand {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                }
                Image(systemName: "folder.fill")
                    .font(.system(size: compact ? 12 : 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: tile, height: tile)

            Text(DekpopBrand.displayName)
                .font(.system(size: compact ? 17 : 22, weight: .heavy, design: .rounded))
                .foregroundStyle(onBrand ? Color.white : Color.primary)

            if !compact {
                Text("files")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(onBrand ? Color.white : AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            onBrand
                                ? Color.white.opacity(0.20)
                                : AppTheme.accent.opacity(0.12)
                        )
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DekpopBrand.displayName)
    }
}

/// Branded hero card at the top of the Files browser. Shows the product
/// identity, device, iOS version and whether container access is ready.
struct DekpopHeroCard: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState

    private var isReady: Bool { appState.exploitStatus.isSuccess }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.brandGradient

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 180, height: 180)
                .offset(x: 62, y: -72)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 130, height: 130)
                .offset(x: -150, y: 92)

            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    DekpopWordmark(onBrand: true)
                    Spacer(minLength: 4)
                    statusPill
                }

                Text(language.text("dekpop.tagline"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.9))

                HStack(spacing: 8) {
                    infoChip(icon: "iphone", value: AppInfo.displayMachineName)
                    infoChip(icon: "checkmark.circle", value: "iOS \(AppInfo.osVersion)")
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.brandMiddle.opacity(0.24), radius: 14, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isReady ? Color.green : Color.white.opacity(0.92))
                .frame(width: 6, height: 6)
            Text(language.text(isReady ? "dekpop.status_ready" : "dekpop.status_preparing"))
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.18)))
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(value)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.16)))
    }
}

/// Small signature at the bottom of the app list.
struct DekpopFooterView: View {
    var body: some View {
        VStack(spacing: 3) {
            Text(DekpopBrand.displayName)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(.secondary)
            Text("files · \(DekpopBrand.version) (\(DekpopBrand.build))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityHidden(true)
    }
}

/// Two-language switcher shown in every Files toolbar. Selecting an option
/// writes `appLanguage`, which the root app observes to swap the locale and
/// the localized string bundle immediately.
struct DekpopLanguageMenu: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.defaultRawValue
    @Environment(\.appLanguage) private var language

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    languageCode = option.rawValue
                } label: {
                    if languageCode == option.rawValue {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
        }
        .accessibilityLabel(language.text("dekpop.language"))
    }
}

/// Discoverable segmented switcher at the top of the Files root list.
struct DekpopLanguagePicker: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.defaultRawValue
    @Environment(\.appLanguage) private var language

    var body: some View {
        Picker(language.text("dekpop.language"), selection: $languageCode) {
            ForEach(AppLanguage.allCases) { option in
                Text(option.displayName).tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(language.text("dekpop.language"))
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.24), tint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 9)
        .background(.bar)
    }
}

/// Brand tile used wherever an app avatar is shown. Drawn in SwiftUI so the
/// identity does not depend on a bundled image resource.
struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            AppTheme.brandGradient
            Image(systemName: "folder.fill")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}
