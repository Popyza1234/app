import SwiftUI

/// dekpop ships with a single feature: Files.
/// There is no tab bar, dashboard, patches, cleaner, wallpaper lab,
/// onboarding or update prompt — the Files browser *is* the app.
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filesTabs = FilesTabSession()
    @State private var launchGone = false
    @State private var announcement: DekpopAnnouncement?
    @State private var showingThemePicker = false
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var license = LicenseManager.shared

    var body: some View {
        ZStack {
            // Layered brand backdrop for the whole app: the moving aurora plus
            // the palette mesh that gives every surface something to sit on.
            ZStack {
                DekpopAuroraBackground()
                DekpopMeshBackdrop()
                    .opacity(0.85)
            }
            .ignoresSafeArea()

            if license.isLicensed {
                AppDataBrowserView(tabSession: $filesTabs)
                    .tint(AppTheme.accent)
                    .imageScale(.small)
                    .background(Color.clear)
                    // Rebuild the browser when the palette changes so every
                    // theme-dependent colour is resolved again immediately.
                    .id(theme.selection)
            } else {
                LicenseGateView()
            }

            if !launchGone {
                DekpopLaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let announcement {
                AnnouncementView(announcement: announcement) {
                    self.announcement = nil
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .environment(\.dekpopOpenThemePicker, { showingThemePicker = true })
        .sheet(isPresented: $showingThemePicker) {
            DekpopThemePicker()
                .dekpopSheetCorners()
        }
        .task {
            await license.start()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                    launchGone = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.35)) {
                    announcement = AnnouncementStore.current
                }
            }
        }
    }
}
