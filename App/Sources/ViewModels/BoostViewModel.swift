import Foundation

/// Status line of the main window, kept as structured data so the view only renders it.
enum BoostStatus: Equatable {
    case reading
    case current(key: String, value: String)
    case readFailed

    var message: String {
        switch self {
        case .reading:
            return L10n.t("status.reading")
        case .current(let key, let value):
            return L10n.t("status.current", key, value)
        case .readFailed:
            return L10n.t("status.readFailed")
        }
    }

    var isError: Bool {
        if case .readFailed = self { return true }
        return false
    }
}

@MainActor
final class BoostViewModel: ObservableObject {
    @Published private(set) var state: ThrottleState = .unknown
    @Published private(set) var status: BoostStatus?
    @Published private(set) var isBusy = false

    private let manager: TimeMachineManager
    private var hasLoadedInitialState = false

    init(manager: TimeMachineManager = TimeMachineManager()) {
        self.manager = manager
    }

    /// Short description of the current state, shown below the title.
    var stateDescription: String {
        switch state {
        case .throttleDisabled: return L10n.t("subtitle.accelerated")
        case .throttleEnabled: return L10n.t("subtitle.default")
        case .unknown: return L10n.t("main.reading")
        }
    }

    var statusMessage: String { status?.message ?? "" }
    var statusIsError: Bool { status?.isError ?? false }
    var canRefresh: Bool { !isBusy }

    /// Reads the state once, when the window first appears.
    func loadInitialState() async {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true
        await refresh()
    }

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        status = .reading
        defer { isBusy = false }

        do {
            let current = try await manager.currentState()
            state = current
            status = .current(key: ThrottleParameter.key, value: current.sysctlValue ?? "")
        } catch {
            state = .unknown
            status = .readFailed
        }
    }
}
