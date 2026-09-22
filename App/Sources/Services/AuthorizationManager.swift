import Foundation

/// Administrator operations, expressed as fixed commands: no user input is ever
/// interpolated into the shell script that `osascript` runs, exactly like the legacy GUI.
enum AdminShellCommand: Equatable {
    /// `sysctl -n <key>` with administrator privileges (fallback read).
    case readThrottleState
    /// Sets the value and reads it back inside a single authorization, so the
    /// result is never reported from an expired credential.
    case applyThrottleState(ThrottleValue)

    var shellCommand: String {
        let sysctl = ThrottleParameter.sysctlPath
        let key = ThrottleParameter.key
        switch self {
        case .readThrottleState:
            return "\(sysctl) -n \(key)"
        case .applyThrottleState(let value):
            return "\(sysctl) \(key)=\(value.rawValue) >/dev/null && \(sysctl) -n \(key)"
        }
    }
}

/// Runs one command through the system administrator authorization dialog.
/// The privileged helper (LaunchDaemon/XPC) is deliberately out of scope for now,
/// keeping the same security boundary as the legacy GUI: every operation asks again.
final class AuthorizationManager {
    private static let osascriptPath = "/usr/bin/osascript"

    func runWithAdministratorPrivileges(_ command: AdminShellCommand) async throws -> ProcessResult {
        // `shellCommand` is built from constants in `AdminShellCommand` only.
        let script = "do shell script \"\(command.shellCommand)\" with administrator privileges"
        return try await ProcessRunner.run(executable: Self.osascriptPath, arguments: ["-e", script])
    }

    /// `osascript` reports a cancelled authorization as error -128.
    static func isAuthorizationCancelled(_ result: ProcessResult) -> Bool {
        result.output.contains("-128")
    }
}
