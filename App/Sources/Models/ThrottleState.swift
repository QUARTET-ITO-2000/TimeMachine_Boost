import Foundation

/// The kernel interface that Time Machine low-priority I/O throttling is exposed through.
enum ThrottleParameter {
    /// `debug.lowpri_throttle_enabled`
    static let key = "debug.lowpri_throttle_enabled"
    static let sysctlPath = "/usr/sbin/sysctl"
}

/// State of the low-priority I/O throttle that Time Machine backups run under.
enum ThrottleState: Equatable {
    /// `debug.lowpri_throttle_enabled = 1`, the system default: throttling is on.
    case throttleEnabled
    /// `debug.lowpri_throttle_enabled = 0`, boost mode: throttling is off.
    case throttleDisabled
    /// The value could not be read (restricted environment, missing tool, unexpected output).
    case unknown

    init?(sysctlValue: String) {
        switch sysctlValue {
        case "0": self = .throttleDisabled
        case "1": self = .throttleEnabled
        default: return nil
        }
    }

    /// The sysctl value this state corresponds to; `nil` for `.unknown`.
    var sysctlValue: String? {
        switch self {
        case .throttleEnabled: return "1"
        case .throttleDisabled: return "0"
        case .unknown: return nil
        }
    }

    /// `true` when boost mode is active, i.e. low-priority I/O throttling is disabled.
    var isBoostEnabled: Bool {
        self == .throttleDisabled
    }

    var isKnown: Bool {
        self != .unknown
    }
}
