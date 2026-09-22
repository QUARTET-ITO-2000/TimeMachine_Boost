import Foundation
import OSLog

/// Applies an interface language exactly like the legacy GUI: store the choice, then
/// relaunch so the bundle loads the matching `Localizable.strings`.
enum LanguageManager {
    static let defaultsKey = "TMBLanguage"

    private static let logger = Logger(subsystem: "local.mokuchonu.TimeMachineBoost", category: "language")

    /// Stores the language and relaunches the app. Returns `false` when the relaunch
    /// could not be started, in which case the caller should stay running.
    @discardableResult
    static func apply(_ language: AppLanguage) async -> Bool {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: defaultsKey)
        defaults.set([language.rawValue], forKey: "AppleLanguages")
        defaults.synchronize()

        return await relaunch()
    }

    private static func relaunch() async -> Bool {
        let bundlePath = Bundle.main.bundlePath
        do {
            let result = try await ProcessRunner.run(
                executable: "/usr/bin/open",
                arguments: ["-n", bundlePath]
            )
            guard result.exitStatus == 0 else {
                logger.error(
                    "Relaunch failed with status \(result.exitStatus, privacy: .public): \(result.output, privacy: .public)"
                )
                return false
            }
            return true
        } catch {
            logger.error("Relaunch failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
