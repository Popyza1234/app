import SwiftUI
import UIKit

/// The 2026 layer of the design system.
///
/// Everything here is palette aware, so changing the theme restyles the whole
/// app at once. Screens compose these pieces instead of inventing their own
/// corner radii, hairlines and shadows.

// MARK: - Tokens

enum DekpopRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 24
    static let xlarge: CGFloat = 30
}

enum DekpopMotion {
    static let tap = Animation.spring(response: 0.26, dampingFraction: 0.82)
    static let transition = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let drift = Animation.easeInOut(duration: 11)

    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - Surfaces

/// Frosted card with a hairline that catches the palette, a soft outer shadow
/// and a bright top edge — the surface every screen is built from.
struct DekpopGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var accent: Color?
    var padding: CGFloat
    var cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(
        accent: Color? = nil,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = DekpopRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    private var glow: Color { accent ?? AppTheme.accent }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.65),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.16),
                                glow.opacity(colorScheme == .dark ? 0.22 : 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.07), radius: 18, x: 0, y: 10)
            .shadow(color: (accent ?? AppTheme.brandMiddle).opacity(colorScheme == .dark ? 0.16 : 0.10), radius: 26, x: 0, y: 14)
    }
}

/// Small uppercase eyebrow above a group of rows.
struct DekpopSectionHeader: View {
    let title: String
    var icon: String?
    var tint: Color = AppTheme.accent

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }

            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Pill for state: a dot (or symbol) plus a short label.
struct DekpopStatusChip: View {
    let text: String
    var tint: Color = AppTheme.accent
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
            }

            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.24), lineWidth: 0.8))
    }
}

/// Full-width gradient button: the one primary action on a screen.
struct DekpopGradientButtonStyle: ButtonStyle {
    var tint: Color?
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: DekpopRadius.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint ?? AppTheme.accent, AppTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DekpopRadius.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(
                color: (tint ?? AppTheme.accent).opacity(configuration.isPressed ? 0.18 : 0.34),
                radius: configuration.isPressed ? 8 : 18,
                x: 0,
                y: configuration.isPressed ? 4 : 9
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(DekpopMotion.tap, value: configuration.isPressed)
    }
}

/// Quiet secondary action, used next to a gradient button.
struct DekpopQuietButtonStyle: ButtonStyle {
    var height: CGFloat = 42

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: DekpopRadius.small, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DekpopRadius.small, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
            .animation(DekpopMotion.tap, value: configuration.isPressed)
    }
}

// MARK: - Backdrop

/// Layered mesh of palette light. Sits behind every screen, drifts slowly, and
/// stops dead when the user asks for reduced motion.
struct DekpopMeshBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared

    @State private var phase: CGFloat = 0

    private var palette: DekpopPalette { theme.palette }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: palette.brandStart).opacity(0.55),
                    Color.clear,
                    Color(uiColor: palette.brandEnd).opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            blob(palette.accent.opacity(0.32), size: 430, blur: 96)
                .offset(x: -140 + phase * 46, y: -280 + phase * 34)

            blob(palette.accentSecondary.opacity(0.24), size: 350, blur: 104)
                .offset(x: 160 - phase * 40, y: 250 - phase * 46)

            blob(Color(uiColor: palette.brandMiddle).opacity(0.20), size: 300, blur: 110)
                .offset(x: 24 + phase * 22, y: -40 + phase * 58)

            blob(Color(uiColor: palette.brandEnd).opacity(0.14), size: 250, blur: 90)
                .offset(x: -170 - phase * 28, y: 150 + phase * 30)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion, phase == 0 else { return }
            withAnimation(DekpopMotion.drift.repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat, blur: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
    }
}

// MARK: - View helpers

extension View {
    /// Rounds the sheet corner on OS versions that support it, so sheets match
    /// the rest of the language instead of the default radius.
    @ViewBuilder
    func dekpopSheetCorners(_ radius: CGFloat = DekpopRadius.xlarge) -> some View {
        if #available(iOS 16.4, *) {
            presentationCornerRadius(radius)
        } else {
            self
        }
    }

    /// Lets the brand backdrop show through list and scroll containers.
    @ViewBuilder
    func dekpopClearScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
