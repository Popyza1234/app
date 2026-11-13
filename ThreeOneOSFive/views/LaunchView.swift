import SwiftUI

/// Branded full-screen launch overlay. Shown once per launch while the app
/// warms up; it always yields to the Files browser after a short minimum time
/// so the interface never feels blocked.
struct DekpopLaunchView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var started = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var floating = false

    var body: some View {
        ZStack {
            AppTheme.brandGradient
                .ignoresSafeArea()

            decoration

            VStack(spacing: 18) {
                Spacer()

                logo
                    .scaleEffect(started ? 1 : 0.82)
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
                .offset(y: started ? 0 : 10)

                Spacer()

                VStack(spacing: 14) {
                    progressBar

                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .animation(.easeInOut(duration: 0.2), value: statusText)
                }

                Text("files · \(DekpopBrand.version) (\(DekpopBrand.build))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(0.05)) {
                started = true
            }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }

    private var decoration: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 260, height: 260)
                .offset(x: floating ? 108 : 130, y: floating ? -262 : -240)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 200, height: 200)
                .offset(x: floating ? -138 : -160, y: floating ? 224 : 200)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .offset(x: floating ? -100 : -120, y: floating ? -324 : -300)
        }
        .blur(radius: 2)
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
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .frame(width: 108, height: 108)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.22))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.65), .white, .white.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60)
                .offset(x: shimmerPhase * 180)
                .mask(Capsule())
        }
        .frame(width: 180, height: 6)
        .mask(Capsule())
    }

    private var statusText: String {
        // There is no unsupported state anymore: every iOS version string
        // (27.0.1 included) is accepted, so this screen must never be able to
        // display "this iOS version is not supported yet".
        if !appState.kernelExploitRunning {
            return language.text("dekpop.status_ready")
        }
        return language.text("launch.status_loading")
    }
}
