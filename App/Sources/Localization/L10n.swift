import Foundation

/// Thin wrapper around the bundle lookup so views never contain user-facing literals.
enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
    }
}
