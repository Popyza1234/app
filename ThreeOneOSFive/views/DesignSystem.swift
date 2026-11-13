import SwiftUI
import UIKit

/// dekpop is a Files-only app. These constants are the single source of truth
/// for the product identity shown in the UI.
enum DekpopBrand {
    static let displayName = "dekpop"
    static let version = "1.5.0"
    static let build = "14"
}

// MARK: - Themes

/// Every look the app can wear. The palette drives accents, icons, gradients,
/// the hero card and the launch screen; the selection is persisted.
enum DekpopPaletteID: String, CaseIterable, Identifiable {
    case violet
    case midnight
    case sunset
    case sakura
    case forest
    case mono

    var id: String { rawValue }

    var titleKey: String { "theme.\(rawValue)" }
}

/// One selectable theme. Colours are stored as `UIColor` so light/dark mode
/// still resolves automatically while the palette itself changes.
struct DekpopPalette: Identifiable {
    let id: DekpopPaletteID
    let lightAccent: UIColor
    let darkAccent: UIColor
    let lightSecondary: UIColor
    let darkSecondary: UIColor
    let brandStart: UIColor
    let brandMiddle: UIColor
    let brandEnd: UIColor

    var accent: Color { AppTheme.dynamic(light: lightAccent, dark: darkAccent) }
    var accentSecondary: Color { AppTheme.dynamic(light: lightSecondary, dark: darkSecondary) }

    var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(uiColor: brandStart), Color(uiColor: brandMiddle), Color(uiColor: brandEnd)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    static func palette(for id: DekpopPaletteID) -> DekpopPalette {
        switch id {
        case .violet:
            return DekpopPalette(
                id: .violet,
                lightAccent: rgb(0.39, 0.24, 0.90),
                darkAccent: rgb(0.70, 0.58, 1.00),
                lightSecondary: rgb(0.93, 0.24, 0.52),
                darkSecondary: rgb(1.00, 0.57, 0.76),
                brandStart: rgb(0.15, 0.09, 0.42),
                brandMiddle: rgb(0.43, 0.25, 0.94),
                brandEnd: rgb(0.98, 0.32, 0.58)
            )
        case .midnight:
            return DekpopPalette(
                id: .midnight,
                lightAccent: rgb(0.05, 0.42, 0.86),
                darkAccent: rgb(0.36, 0.72, 1.00),
                lightSecondary: rgb(0.00, 0.62, 0.74),
                darkSecondary: rgb(0.32, 0.92, 0.96),
                brandStart: rgb(0.02, 0.07, 0.24),
                brandMiddle: rgb(0.06, 0.33, 0.74),
                brandEnd: rgb(0.10, 0.76, 0.94)
            )
        case .sunset:
            return DekpopPalette(
                id: .sunset,
                lightAccent: rgb(0.90, 0.35, 0.08),
                darkAccent: rgb(1.00, 0.66, 0.38),
                lightSecondary: rgb(0.92, 0.18, 0.42),
                darkSecondary: rgb(1.00, 0.52, 0.62),
                brandStart: rgb(0.34, 0.08, 0.12),
                brandMiddle: rgb(0.86, 0.30, 0.13),
                brandEnd: rgb(0.99, 0.70, 0.22)
            )
        case .sakura:
            return DekpopPalette(
                id: .sakura,
                lightAccent: rgb(0.78, 0.18, 0.46),
                darkAccent: rgb(1.00, 0.62, 0.78),
                lightSecondary: rgb(0.84, 0.36, 0.70),
                darkSecondary: rgb(0.98, 0.70, 0.92),
                brandStart: rgb(0.32, 0.07, 0.20),
                brandMiddle: rgb(0.80, 0.25, 0.52),
                brandEnd: rgb(0.99, 0.74, 0.80)
            )
        case .forest:
            return DekpopPalette(
                id: .forest,
                lightAccent: rgb(0.04, 0.48, 0.34),
                darkAccent: rgb(0.34, 0.88, 0.66),
                lightSecondary: rgb(0.52, 0.68, 0.14),
                darkSecondary: rgb(0.80, 0.92, 0.38),
                brandStart: rgb(0.02, 0.18, 0.14),
                brandMiddle: rgb(0.04, 0.48, 0.34),
                brandEnd: rgb(0.62, 0.86, 0.36)
            )
        case .mono:
            return DekpopPalette(
                id: .mono,
                lightAccent: rgb(0.22, 0.22, 0.26),
                darkAccent: rgb(0.88, 0.89, 0.94),
                lightSecondary: rgb(0.44, 0.46, 0.52),
                darkSecondary: rgb(0.64, 0.66, 0.72),
                brandStart: rgb(0.08, 0.08, 0.10),
                brandMiddle: rgb(0.28, 0.28, 0.33),
                brandEnd: rgb(0.55, 0.56, 0.63)
            )
        }
    }
}

/// Holds the active palette and remembers it between launches.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let storageKey = "dekpop.theme"

    @Published var selection: DekpopPaletteID {
        didSet {
            guard selection != oldValue else { return }
            UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    var palette: DekpopPalette { DekpopPalette.palette(for: selection) }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        selection = DekpopPaletteID(rawValue: stored) ?? .violet
    }
}

enum DekpopHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Theme-aware colours. Every call site keeps using `AppTheme.accent`,
/// `AppTheme.brandGradient`, … and simply follows the selected palette.
enum AppTheme {
    private static var palette: DekpopPalette { ThemeManager.shared.palette }

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static var accent: Color { palette.accent }
    static var accentSecondary: Color { palette.accentSecondary }

    static var brandStart: Color { Color(uiColor: palette.brandStart) }
    static var brandMiddle: Color { Color(uiColor: palette.brandMiddle) }
    static var brandEnd: Color { Color(uiColor: palette.brandEnd) }

    static var brandGradient: LinearGradient { palette.brandGradient }

    static var softGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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

/// Soft, slowly drifting palette-coloured light behind the Files list.
struct DekpopAnimatedBackground: View {
    var palette: DekpopPalette = ThemeManager.shared.palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            glow(palette.accent.opacity(0.22), size: 340, blur: 70)
                .offset(x: drifting ? -120 : -50, y: drifting ? -250 : -170)

            glow(palette.accentSecondary.opacity(0.18), size: 300, blur: 80)
                .offset(x: drifting ? 140 : 70, y: drifting ? 280 : 210)

            glow(Color(uiColor: palette.brandMiddle).opacity(0.14), size: 260, blur: 90)
                .offset(x: drifting ? -40 : 10, y: drifting ? 60 : 100)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, !drifting else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                drifting = true
            }
        }
    }

    private func glow(_ color: Color, size: CGFloat, blur: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
    }
}

/// Springy press feedback used by cards and pickers.
struct DekpopPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Sheet that lets the user switch the whole app's look, with a live preview
/// card per palette. Changes apply immediately and are remembered.
struct DekpopThemePicker: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(language.text("theme.intro"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DekpopPaletteID.allCases) { id in
                            card(id)
                        }
                    }

                    Text(language.text("theme.footer"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(DekpopAnimatedBackground(palette: theme.palette).ignoresSafeArea())
            .navigationTitle(language.text("theme.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func card(_ id: DekpopPaletteID) -> some View {
        let palette = DekpopPalette.palette(for: id)
        let selected = theme.selection == id

        return Button {
            guard theme.selection != id else { return }
            DekpopHaptics.select()
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78)) {
                theme.selection = id
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                preview(palette)

                HStack(spacing: 5) {
                    Text(language.text(id.titleKey))
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 2)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.accent)
                    }
                }

                HStack(spacing: 5) {
                    Circle().fill(palette.accent).frame(width: 9, height: 9)
                    Circle().fill(palette.accentSecondary).frame(width: 9, height: 9)
                    Circle().fill(Color(uiColor: palette.brandMiddle)).frame(width: 9, height: 9)
                    Circle().fill(Color(uiColor: palette.brandEnd)).frame(width: 9, height: 9)
                    Spacer()
                }
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        selected ? palette.accent : Color.primary.opacity(0.06),
                        lineWidth: selected ? 2 : 1
                    )
            )
            .shadow(
                color: Color(uiColor: palette.brandMiddle).opacity(selected ? 0.30 : 0.10),
                radius: selected ? 14 : 6,
                x: 0,
                y: selected ? 7 : 3
            )
        }
        .buttonStyle(DekpopPressStyle(scale: 0.95))
        .accessibilityLabel(language.text(id.titleKey))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func preview(_ palette: DekpopPalette) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(palette.brandGradient)

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 70, height: 70)
                .offset(x: 76, y: -26)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.92)).frame(width: 9, height: 9)
                    Capsule().fill(Color.white.opacity(0.55)).frame(width: 24, height: 5)
                    Spacer(minLength: 0)
                }
                Capsule().fill(Color.white.opacity(0.38)).frame(width: 58, height: 5)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 40, height: 5)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: 34, height: 9)
                    Capsule().fill(Color.white.opacity(0.30)).frame(width: 22, height: 9)
                    Spacer(minLength: 0)
                }
            }
            .padding(9)
        }
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var drift = false
    @State private var sweep: CGFloat = -1.2

    private var isReady: Bool { appState.exploitStatus.isSuccess }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.brandGradient

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 180, height: 180)
                .offset(x: drift ? 46 : 62, y: drift ? -56 : -72)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 130, height: 130)
                .offset(x: drift ? -134 : -150, y: drift ? 106 : 92)

            sheen

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
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.brandMiddle.opacity(0.28), radius: 16, x: 0, y: 7)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                drift = true
            }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                sweep = 1.4
            }
        }
    }

    private var sheen: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.20),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 96)
            .rotationEffect(.degrees(16))
            .offset(x: sweep * proxy.size.width)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

private struct DekpopOpenThemePickerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Present the theme picker. Handled by the root view so the sheet lives
    /// outside the subtree that is rebuilt when the palette changes.
    var dekpopOpenThemePicker: () -> Void {
        get { self[DekpopOpenThemePickerKey.self] }
        set { self[DekpopOpenThemePickerKey.self] = newValue }
    }
}

/// Toolbar entry point for the theme picker.
struct DekpopThemeToolbarButton: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dekpopOpenThemePicker) private var openThemePicker

    var body: some View {
        Button {
            DekpopHaptics.tap()
            openThemePicker()
        } label: {
            Image(systemName: "paintpalette")
        }
        .accessibilityLabel(language.text("theme.title"))
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
