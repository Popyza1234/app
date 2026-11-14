import SwiftUI

/// dekpop ships with exactly two languages: English and Thai.
enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case thai = "th"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .thai: return "ไทย"
        }
    }

    /// Secondary label used by the onboarding language list.
    var nativeHint: String {
        switch self {
        case .english: return "English"
        case .thai: return "ภาษาไทย"
        }
    }

    /// Old builds shipped other languages. Stored values that no longer exist
    /// must fall back to English instead of producing a nil language after an update.
    static func resolving(_ code: String) -> AppLanguage {
        AppLanguage(rawValue: code) ?? .english
    }

    /// A Thai device starts in Thai; every other device starts in English.
    static var preferredDefault: AppLanguage {
        guard let first = Locale.preferredLanguages.first else { return .english }
        return first.hasPrefix("th") ? .thai : .english
    }

    static var defaultRawValue: String { preferredDefault.rawValue }

    func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private var localizedBundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}
