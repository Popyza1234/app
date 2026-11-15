import SwiftUI

/// dekpop is a Files app with three home sections: Apps, Shortcuts and Mods.
/// Container browsing is the core; there is no patch, cleaner, wallpaper lab,
/// onboarding or update prompt.
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filesTabs = FilesTabSession()
    @State private var launchGone = false
    @State private var announcement: DekpopAnnouncement?
    @State private var showingThemePicker = false
    // Subscribing here refreshes the top-level tint when the palette changes;
    // individual screens observe the same singleton and redraw in place.
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            // One static brand backdrop for the whole app. The old version
            // stacked an animated 30 fps Canvas, an animated four-blur mesh and
            // a third animated blurred background on the list itself.
            DekpopAuroraBackground()

            AppDataBrowserView(tabSession: $filesTabs)
                .tint(theme.palette.accent)
                .imageScale(.small)
                .background(Color.clear)

            if !launchGone {
                DekpopLaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let announcement {
                AnnouncementView(announcement: announcement) {
                    AnnouncementStore.markSeen(announcement)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    launchGone = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.22)) {
                    announcement = AnnouncementStore.current
                }
            }
        }
    }
}
