import SwiftUI

/// Brand-wide animated backdrop: slowly drifting aurora gradients plus a light
/// particle field.
///
/// Everything is drawn inside a single `Canvas` driven by a `TimelineView`, so
/// the effect costs one drawing pass per frame instead of dozens of animating
/// views — it stays smooth while the Files browser scrolls on top of it.
///
/// - Note: honours Reduce Motion by freezing on a tasteful static frame.
struct DekpopAuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                AppTheme.pageBackground

                if reduceMotion {
                    aurora(size: size, time: 0)
                    particleField(size: size, time: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        ZStack {
                            aurora(size: size, time: time)
                            particleField(size: size, time: time)
                        }
                    }
                }

                // Keeps the navigation bar and status bar legible.
                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.28 : 0.0),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Layers

    private func aurora(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let palette: [Color] = [.purple, .pink, .indigo, .cyan]
            let base = min(canvasSize.width, canvasSize.height)
            let full = Path(CGRect(origin: .zero, size: canvasSize))

            for (index, color) in palette.enumerated() {
                let phase = Double(index) * 1.9
                let speed = 0.09 + Double(index) * 0.035
                let radius = base * (0.40 + 0.06 * sin(time * speed + phase))
                let center = CGPoint(
                    x: canvasSize.width * (0.5 + 0.32 * sin(time * speed * 0.9 + phase)),
                    y: canvasSize.height * (0.45 + 0.30 * cos(time * speed * 0.75 + phase * 1.4))
                )

                let shading = GraphicsContext.Shading.radialGradient(
                    Gradient(colors: [color.opacity(0.42), color.opacity(0.02), color.opacity(0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
                context.fill(full, with: shading)
            }
        }
        .opacity(colorScheme == .dark ? 1 : 0.75)
        .blendMode(colorScheme == .dark ? .plusLighter : .normal)
    }

    private func particleField(size: CGSize, time: Double) -> some View {
        Canvas { context, canvasSize in
            let count = 28
            for index in 0..<count {
                let x = random(index, 1.7) * canvasSize.width
                let speed = 7 + random(index, 2.3) * 16
                let travel = canvasSize.height + 90
                let offset = random(index, 3.1) * travel
                let y = canvasSize.height + 45 - ((time * speed + offset).truncatingRemainder(dividingBy: travel))

                let radius = 1.1 + random(index, 4.4) * 1.9
                let twinkle = 0.5 + 0.5 * sin(time * 0.9 + Double(index))
                let opacity = 0.07 + 0.13 * twinkle

                let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
        .opacity(colorScheme == .dark ? 1 : 0.5)
    }

    /// Deterministic pseudo-random in 0..<1 so particles stay put between frames.
    private func random(_ index: Int, _ salt: Double) -> Double {
        let raw = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return raw - floor(raw)
    }
}

/// Soft press feedback used by the activation screen's buttons.
struct DekpopPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
