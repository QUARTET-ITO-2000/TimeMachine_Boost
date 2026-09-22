import Foundation

/// Status line of the main window, kept as structured data so the view only renders it.
enum BoostStatus: Equatable {
    case reading
    case current(key: String, value: String)
    case readFailed
    case readingPrivileged
    case privilegedReadDone(key: String, value: String)
    case privilegedReadFailed(exitStatus: Int32)
    case authorizationCancelled(short: Bool)
    case applying
    case applied(boostEnabled: Bool, key: String, value: String)
    case applyFailed(exitStatus: Int32)
    case relaunchFailed(String)

    var message: String {
        switch self {
        case .reading:
            return L10n.t("status.reading")
        case .current(let key, let value):
            return L10n.t("status.current", key, value)
        case .readFailed:
            return L10n.t("status.readFailed")
        case .readingPrivileged:
            return L10n.t("status.readingPrivileged")
        case .privilegedReadDone(let key, let value):
            return L10n.t("status.privilegedReadDone", key, value)
        case .privilegedReadFailed(let exitStatus):
            return L10n.t("status.privilegedReadFailed", exitStatus)
        case .authorizationCancelled(let short):
            return L10n.t(short ? "auth.cancelledShort" : "auth.cancelled")
        case .applying:
            return L10n.t("status.applying")
        case .applied(let boostEnabled, let key, let value):
            return L10n.t(
                boostEnabled ? "status.toggleDone.accelerated" : "status.toggleDone.default",
                key,
                value
            )
        case .applyFailed(let exitStatus):
            return L10n.t("status.toggleFailed", exitStatus)
        case .relaunchFailed(let reason):
            return L10n.t("status.relaunchFailed", reason)
        }
    }

    var isError: Bool {
        switch self {
        case .reading, .current, .readingPrivileged, .privilegedReadDone, .applying, .applied:
            return false
        case .readFailed, .privilegedReadFailed, .authorizationCancelled, .applyFailed, .relaunchFailed:
            return true
        }
    }
}

@MainActor
final class BoostViewModel: ObservableObject {
    @Published private(set) var state: ThrottleState = .unknown
    @Published private(set) var status: BoostStatus?
    @Published private(set) var isBusy = false
    @Published var languageSelection: AppLanguage
    @Published var isRestartPromptPresented = false

    private let manager: TimeMachineManager
    private let effectiveLanguage: AppLanguage
    private var hasLoadedInitialState = false

    init(
        manager: TimeMachineManager = TimeMachineManager(),
        language: AppLanguage = AppLanguage.current
    ) {
        self.manager = manager
        self.effectiveLanguage = language
        self.languageSelection = language
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
    var canToggle: Bool { state.isKnown && !isBusy }

    /// The legacy GUI only offered the privileged read while the state was unknown.
    var canReadWithPrivileges: Bool { !state.isKnown && !isBusy }

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

    /// Reads the state through the administrator authorization dialog.
    func readStateWithAdministratorPrivileges() async {
        guard !isBusy else { return }
        isBusy = true
        status = .readingPrivileged
        defer { isBusy = false }

        do {
            let current = try await manager.currentStateWithAuthorization()
            state = current
            status = .privilegedReadDone(key: ThrottleParameter.key, value: current.sysctlValue ?? "")
        } catch {
            state = .unknown
            switch error {
            case TimeMachineError.authorizationCancelled:
                status = .authorizationCancelled(short: true)
            case TimeMachineError.toolUnavailable, TimeMachineError.applyFailed:
                status = .privilegedReadFailed(exitStatus: 1)
            case TimeMachineError.stateUnreadable(let exitStatus, _):
                status = .privilegedReadFailed(exitStatus: exitStatus)
            default:
                status = .privilegedReadFailed(exitStatus: 1)
            }
        }
    }

    /// Turns boost mode on or off. The toggle reflects the verified result, so a
    /// cancelled or failed operation leaves it showing the real system state.
    func setBoost(enabled: Bool) async {
        guard state.isKnown, !isBusy else { return }
        isBusy = true
        status = .applying
        defer { isBusy = false }

        do {
            let applied = try await manager.setBoost(enabled: enabled)
            state = applied
            status = .applied(
                boostEnabled: applied.isBoostEnabled,
                key: ThrottleParameter.key,
                value: applied.sysctlValue ?? ""
            )
        } catch {
            switch error {
            case TimeMachineError.authorizationCancelled:
                status = .authorizationCancelled(short: false)
            case TimeMachineError.applyFailed(let exitStatus):
                status = .applyFailed(exitStatus: exitStatus)
            case TimeMachineError.verificationFailed:
                status = .applyFailed(exitStatus: 0)
            default:
                status = .applyFailed(exitStatus: 1)
            }
        }
    }

    // MARK: - Language

    /// The legacy GUI asked for confirmation before restarting in the new language.
    func languageSelectionChanged() {
        guard languageSelection != effectiveLanguage else { return }
        isRestartPromptPresented = true
    }

    func cancelLanguageChange() {
        isRestartPromptPresented = false
        languageSelection = effectiveLanguage
    }

    /// Stores the language and starts a relaunch. `true` means the caller should quit.
    func applyLanguageChange() async -> Bool {
        isRestartPromptPresented = false
        let relaunched = await LanguageManager.apply(languageSelection)
        if !relaunched {
            status = .relaunchFailed(L10n.t("error.unknown"))
            languageSelection = effectiveLanguage
        }
        return relaunched
    }
}
