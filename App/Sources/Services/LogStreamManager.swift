import Foundation
import OSLog

/// Streams Time Machine logs into observable state. The view never owns a `Process`.
@MainActor
final class LogStreamManager: ObservableObject {
    /// The log window is created and destroyed by SwiftUI, while the stream is a
    /// single process, so the manager is shared and outlives the window.
    static let shared = LogStreamManager()

    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var status: LogStatus = .preparing
    @Published private(set) var isStreaming = false

    private static let logger = Logger(subsystem: "local.mokuchonu.TimeMachineBoost", category: "log-stream")

    private let logPath: String
    private let predicate = "subsystem == \"com.apple.TimeMachine\""

    private var process: Process?
    private var readHandle: FileHandle?
    private var store = LogStore()

    init(logPath: String = "/usr/bin/log") {
        self.logPath = logPath
    }

    /// Starts a fresh stream. The legacy window always began from a cleared view.
    func restart() {
        stop()
        clear()
        store.appendLine(L10n.t("log.streamStarted"))
        publishStore()
        status = .streaming
        start()
    }

    func start() {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: logPath)
        process.arguments = ["stream", "--predicate", predicate, "--style", "compact"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        self.process = process
        self.readHandle = pipe.fileHandleForReading

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.append(chunk: chunk)
            }
        }

        process.terminationHandler = { [weak self] ended in
            Task { @MainActor [weak self] in
                self?.handleTermination(of: ended)
            }
        }

        do {
            try process.run()
            isStreaming = true
        } catch {
            Self.logger.error(
                "Unable to start log stream: \(error.localizedDescription, privacy: .public)"
            )
            store.appendLine(L10n.t("log.startFailedLine", error.localizedDescription))
            publishStore()
            status = .startFailed
            cleanup()
        }
    }

    /// Stops the stream and releases the process. Safe to call repeatedly.
    func stop() {
        guard let process else { return }
        process.terminationHandler = nil
        readHandle?.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
        cleanup()
    }

    func clear() {
        store.removeAll()
        entries = []
    }

    private func cleanup() {
        readHandle?.readabilityHandler = nil
        process = nil
        readHandle = nil
        isStreaming = false
    }

    private func handleTermination(of ended: Process) {
        guard process === ended else { return }
        cleanup()
        store.appendLine(L10n.t("log.streamEnded"))
        publishStore()
        status = .ended
    }

    /// Feeds streamed text into the buffer.
    private func append(chunk: String) {
        store.append(chunk: chunk)
        publishStore()
    }

    /// The store is a value type, so publish its contents for SwiftUI observers.
    private func publishStore() {
        entries = store.entries
    }
}
