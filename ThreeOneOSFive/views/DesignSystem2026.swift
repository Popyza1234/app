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
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.55),
                                glow.opacity(colorScheme == .dark ? 0.18 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            // One cheap shadow instead of two large, offset shadows. Large
            // multi-layer shadows force an offscreen pass for every card while
            // the list scrolls.
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                radius: 12,
                x: 0,
                y: 5
            )
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

// MARK: - Controls

/// One option in `DekpopSegmentedControl`.
struct DekpopSegment: Identifiable, Equatable {
    let id: String
    let title: String
}

/// Lightweight segmented control built from plain SwiftUI buttons.
///
/// Why not `Picker(.segmented)`: a UIKit segmented control measures itself at
/// its intrinsic width. With long Thai labels it can become wider than the
/// phone, which used to push the whole Files screen past the right bezel.
/// This control divides the available width equally, shrinks text, and can
/// never overflow its parent.
struct DekpopSegmentedControl: View {
    let segments: [DekpopSegment]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                let isSelected = segment.id == selection

                Button {
                    guard !isSelected else { return }
                    DekpopHaptics.select()
                    withAnimation(DekpopMotion.tap) {
                        selection = segment.id
                    }
                } label: {
                    Text(segment.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.accent.opacity(0.18))
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(segment.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }
}

// MARK: - Backdrop

/// Static palette wash used as part of the root backdrop.
///
/// Kept for source compatibility with older call sites, but deliberately
/// static: the previous implementation animated four 250–430 pt circles with
/// 90–110 pt blurs forever, which is one of the most expensive things SwiftUI
/// can do on a low-end GPU.
struct DekpopMeshBackdrop: View {
    @ObservedObject private var theme = ThemeManager.shared

    private var palette: DekpopPalette { theme.palette }

    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: palette.brandStart).opacity(0.24),
                Color.clear,
                Color(uiColor: palette.brandEnd).opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
