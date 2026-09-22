import Foundation
import OSLog

enum TimeMachineError: Error, Equatable {
    /// The tool could not be launched (missing binary, sandbox restriction).
    case toolUnavailable(executable: String)
    /// The tool ran but did not return a usable value.
    case stateUnreadable(exitStatus: Int32, output: String)
    /// The administrator authorization dialog was dismissed.
    case authorizationCancelled
    /// The privileged command failed.
    case applyFailed(exitStatus: Int32)
    /// The privileged command succeeded but the value read back is not the requested one.
    case verificationFailed(expected: String, actual: String)
}

/// Owns every system interaction for the low-priority I/O throttle.
/// Views never run `sysctl` themselves.
final class TimeMachineManager {
    private static let logger = Logger(subsystem: "local.mokuchonu.TimeMachineBoost", category: "throttle")

    private let sysctlPath: String
    private let authorization: AuthorizationManager

    init(
        sysctlPath: String = ThrottleParameter.sysctlPath,
        authorization: AuthorizationManager = AuthorizationManager()
    ) {
        self.sysctlPath = sysctlPath
        self.authorization = authorization
    }

    /// Reads the current state without privileges.
    func currentState() async throws -> ThrottleState {
        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(
                executable: sysctlPath,
                arguments: ["-n", ThrottleParameter.key]
            )
        } catch {
            Self.logger.error("sysctl launch failed: \(String(describing: error), privacy: .public)")
            throw TimeMachineError.toolUnavailable(executable: sysctlPath)
        }

        guard result.exitStatus == 0, let state = ThrottleState(sysctlValue: result.output) else {
            Self.logger.notice(
                "Unusable sysctl result (status \(result.exitStatus, privacy: .public)): \(result.output, privacy: .public)"
            )
            throw TimeMachineError.stateUnreadable(exitStatus: result.exitStatus, output: result.output)
        }
        return state
    }

    /// Reads the state through the administrator authorization dialog.
    func currentStateWithAuthorization() async throws -> ThrottleState {
        let result = try await runPrivileged(.readThrottleState)

        guard result.exitStatus == 0, let state = ThrottleState(sysctlValue: result.output) else {
            // The legacy GUI reported this without a value, keeping the exit status.
            throw TimeMachineError.stateUnreadable(exitStatus: result.exitStatus, output: result.output)
        }
        return state
    }

    /// Switches boost mode on or off and verifies the new value by reading it back.
    @discardableResult
    func setBoost(enabled: Bool) async throws -> ThrottleState {
        let target: ThrottleValue = enabled ? .throttleDisabled : .throttleEnabled
        let result = try await runPrivileged(.applyThrottleState(target))

        guard result.exitStatus == 0 else {
            throw TimeMachineError.applyFailed(exitStatus: result.exitStatus)
        }
        guard result.output == target.rawValue else {
            // Legacy behaviour: a failed readback is reported with exit status 0
            // instead of pretending the change was applied.
            Self.logger.notice(
                "Readback mismatch: expected \(target.rawValue, privacy: .public), got \(result.output, privacy: .public)"
            )
            throw TimeMachineError.verificationFailed(expected: target.rawValue, actual: result.output)
        }
        return ThrottleState(target)
    }

    /// Runs a privileged command, translating a dismissed authorization dialog.
    private func runPrivileged(_ command: AdminShellCommand) async throws -> ProcessResult {
        let result: ProcessResult
        do {
            result = try await authorization.runWithAdministratorPrivileges(command)
        } catch {
            Self.logger.error("osascript launch failed: \(String(describing: error), privacy: .public)")
            // The legacy GUI surfaced this as an ordinary failure with exit status 1.
            throw TimeMachineError.applyFailed(exitStatus: 1)
        }

        if result.exitStatus != 0, AuthorizationManager.isAuthorizationCancelled(result) {
            throw TimeMachineError.authorizationCancelled
        }
        return result
    }
}
