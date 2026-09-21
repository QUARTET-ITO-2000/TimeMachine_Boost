import Foundation
import OSLog

enum TimeMachineError: Error, Equatable {
    /// The tool could not be launched (missing binary, sandbox restriction).
    case toolUnavailable(executable: String)
    /// The tool ran but did not return a usable value.
    case stateUnreadable(exitStatus: Int32, output: String)
}

/// Owns every system interaction for the low-priority I/O throttle.
/// Views never run `sysctl` themselves.
final class TimeMachineManager {
    private static let logger = Logger(subsystem: "local.mokuchonu.TimeMachineBoost", category: "throttle")

    private let sysctlPath: String

    init(sysctlPath: String = ThrottleParameter.sysctlPath) {
        self.sysctlPath = sysctlPath
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
}
