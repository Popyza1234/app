import SwiftUI

/// dekpop ships with a single feature: Files.
/// There is no tab bar, dashboard, patches, cleaner, wallpaper lab,
/// onboarding or update prompt — the Files browser *is* the app.
struct ContentView: View {
    @State private var filesTabs = FilesTabSession()

    var body: some View {
        AppDataBrowserView(tabSession: $filesTabs)
            .tint(AppTheme.accent)
            .imageScale(.small)
            .background(AppTheme.pageBackground)
    }
}
