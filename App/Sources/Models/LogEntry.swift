import Foundation

/// One line of streamed `log stream` output.
struct LogEntry: Identifiable, Equatable {
    let id: Int
    var text: String
}

/// Status of the log window, kept as structured data so the view only renders it.
enum LogStatus: Equatable {
    case preparing
    case streaming
    case startFailed
    case ended

    var message: String {
        switch self {
        case .preparing: return L10n.t("log.preparing")
        case .streaming: return L10n.t("log.streamingStatus")
        case .startFailed: return L10n.t("log.startFailedStatus")
        case .ended: return L10n.t("log.streamEndedStatus")
        }
    }

    var isError: Bool {
        self == .startFailed
    }
}
