import Foundation

/// Holds the streamed log lines and applies the legacy buffer limits:
/// once 600k characters are reached, trim back to 400k.
struct LogStore {
    private(set) var entries: [LogEntry] = []

    private let trimThreshold: Int
    private let trimTarget: Int

    private var pendingLine = ""
    private var nextID = 0
    private var characterCount = 0

    init(trimThreshold: Int = 600_000, trimTarget: Int = 400_000) {
        self.trimThreshold = trimThreshold
        self.trimTarget = trimTarget
    }

    /// Appends a chunk of streamed text, keeping an incomplete trailing line around
    /// until the rest of it arrives.
    mutating func append(chunk: String) {
        var lines = (pendingLine + chunk).components(separatedBy: "\n")
        pendingLine = lines.removeLast()
        for line in lines {
            appendLine(line)
        }
    }

    mutating func appendLine(_ text: String) {
        entries.append(LogEntry(id: nextID, text: text))
        nextID += 1
        characterCount += text.count + 1
        trimIfNeeded()
    }

    mutating func removeAll() {
        entries.removeAll()
        pendingLine = ""
        characterCount = 0
    }

    /// Total number of characters currently held, including line separators.
    var bufferedCharacterCount: Int {
        characterCount
    }

    private mutating func trimIfNeeded() {
        guard characterCount > trimThreshold else { return }

        var removed = 0
        while characterCount > trimTarget, removed < entries.count {
            characterCount -= entries[removed].text.count + 1
            removed += 1
        }
        if removed > 0 {
            entries.removeFirst(removed)
        }
    }
}
