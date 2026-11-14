import SwiftUI
import UIKit

@main
struct DekpopApp: App {
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.defaultRawValue

    init() {
        setupLogCapture()
        Self.configureAppearance()
        log("app: dekpop launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    /// One place for app-wide chrome: transparent blurred bars, clear list
    /// backgrounds so the brand backdrop shows through, and palette-tinted
    /// controls. Individual screens no longer need to repeat any of it.
    private static func configureAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithTransparentBackground()
        navigation.backgroundColor = .clear
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigation.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 33, weight: .heavy)
        ]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = navigation
        bar.compactAppearance = navigation
        bar.scrollEdgeAppearance = navigation

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        let accent = UIColor(AppTheme.accent)
        UISwitch.appearance().onTintColor = accent
        UISegmentedControl.appearance().selectedSegmentTintColor = accent.withAlphaComponent(0.22)
        UISlider.appearance().minimumTrackTintColor = accent
    }

    private var language: AppLanguage {
        AppLanguage.resolving(languageCode)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileOperationCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    // Migrate stored codes from the removed Vietnamese / Chinese builds.
                    if AppLanguage(rawValue: languageCode) == nil {
                        languageCode = AppLanguage.english.rawValue
                    }
                }
        }
    }
}
