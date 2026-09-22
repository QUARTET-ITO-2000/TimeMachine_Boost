import Foundation

/// Interface languages shipped by the app, matching `CFBundleLocalizations`.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"

    var id: String { rawValue }

    /// Always shown in its own language, like the legacy popup.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .spanish: return "Español"
        }
    }

    /// The language the bundle is currently running with.
    static var current: AppLanguage {
        if let stored = UserDefaults.standard.string(forKey: LanguageManager.defaultsKey),
           let storedLanguage = AppLanguage(rawValue: stored) {
            return storedLanguage
        }
        return fromPreferredLocalization(Bundle.main.preferredLocalizations.first)
    }

    /// Maps a bundle localization identifier onto a supported language, English by default.
    static func fromPreferredLocalization(_ identifier: String?) -> AppLanguage {
        guard let identifier else { return .english }
        if identifier.hasPrefix("zh") { return .simplifiedChinese }
        if identifier.hasPrefix("es") { return .spanish }
        return .english
    }
}
