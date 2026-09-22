import Foundation
import OSLog

struct ProcessResult {
    let exitStatus: Int32
    /// stdout and stderr merged and trimmed, matching the legacy implementation.
    let output: String
}

enum ProcessRunnerError: Error {
    case launchFailed(executable: String, underlying: Error)
}

/// Runs system tools off the main thread. Detailed failures are written to the
/// unified log; the UI only shows the short localized message.
enum ProcessRunner {
    private static let logger = Logger(subsystem: "local.mokuchonu.TimeMachineBoost", category: "process")

    static func run(executable: String, arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: runSynchronously(executable: executable, arguments: arguments))
            }
        }
    }

    private static func runSynchronously(
        executable: String,
        arguments: [String]
    ) -> Result<ProcessResult, ProcessRunnerError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            logger.error(
                "Unable to launch \(executable, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .failure(.launchFailed(executable: executable, underlying: error))
        }

        // Read before waiting: the legacy implementation waited first, which can deadlock
        // once a tool produces more output than the pipe buffer holds.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(ProcessResult(exitStatus: process.terminationStatus, output: output))
    }
}
