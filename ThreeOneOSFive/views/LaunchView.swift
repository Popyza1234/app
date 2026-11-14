import SwiftUI

/// Branded launch overlay. Shown once per launch while the app warms up; it
/// always yields to the Files browser after a short minimum time so the
/// interface never feels blocked.
///
/// This screen used to run two `repeatForever` animations (a shimmer sweep and
/// a floating background) while the app was doing its heaviest container scan.
/// It is now a single static gradient with one short fade-in: launch work gets
/// the CPU instead of the animation engine.
struct DekpopLaunchView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var started = false

    var body: some View {
        ZStack {
            AppTheme.brandGradient
                .ignoresSafeArea()

            decoration

            VStack(spacing: 18) {
                Spacer()

                logo
                    .scaleEffect(started ? 1 : 0.92)
                    .opacity(started ? 1 : 0)

                VStack(spacing: 6) {
                    Text(DekpopBrand.displayName)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(language.text("dekpop.tagline"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(started ? 1 : 0)

                Spacer()

                VStack(spacing: 12) {
                    progressBar

                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text("files · \(DekpopBrand.version) (\(DekpopBrand.build))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                started = true
            }
        }
    }

    private var decoration: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 280, height: 280)
                .offset(x: 120, y: -250)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 210, height: 210)
                .offset(x: -150, y: 220)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: -110, y: -310)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.16))
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
            Image(systemName: "folder.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 108, height: 108)
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.20))
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: 92)
        }
        .frame(width: 180, height: 5)
        .clipShape(Capsule())
    }

    private var statusText: String {
        language.text("dekpop.status_ready")
    }
}
