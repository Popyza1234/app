import SwiftUI

/// Brand-wide backdrop.
///
/// Performance contract: this view is completely static. It draws a base fill,
/// one vertical gradient and three radial highlights, all of which the GPU can
/// cache after the first frame. There is no `TimelineView`, no `Canvas`, no
/// `blur(radius:)`, no `repeatForever` animation and no blend mode.
///
/// The old implementation redrew four full-screen radial gradients at 30 fps
/// plus a 28-particle canvas on top of a second animated blurred-layer stack.
/// That combination is what made the Files list stutter and eventually trip the
/// watchdog on lower-spec phones.
struct DekpopAuroraBackground: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var palette: DekpopPalette { theme.palette }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: [
                    Color(uiColor: palette.brandStart).opacity(isDark ? 0.55 : 0.16),
                    Color.clear,
                    Color(uiColor: palette.brandEnd).opacity(isDark ? 0.14 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            radial(
                color: palette.accent,
                opacity: isDark ? 0.28 : 0.20,
                center: UnitPoint(x: 0.08, y: 0.04),
                radius: 430
            )

            radial(
                color: palette.accentSecondary,
                opacity: isDark ? 0.16 : 0.12,
                center: UnitPoint(x: 0.96, y: 0.48),
                radius: 360
            )

            radial(
                color: Color(uiColor: palette.brandMiddle),
                opacity: isDark ? 0.18 : 0.10,
                center: UnitPoint(x: 0.30, y: 1.02),
                radius: 420
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func radial(
        color: Color,
        opacity: Double,
        center: UnitPoint,
        radius: CGFloat
    ) -> some View {
        RadialGradient(
            colors: [color.opacity(opacity), color.opacity(0)],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }
}
