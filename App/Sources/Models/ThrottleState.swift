import Foundation

/// The kernel interface that Time Machine low-priority I/O throttling is exposed through.
enum ThrottleParameter {
    /// `debug.lowpri_throttle_enabled`
    static let key = "debug.lowpri_throttle_enabled"
    static let sysctlPath = "/usr/sbin/sysctl"
}

/// The two values the kernel parameter accepts.
enum ThrottleValue: String {
    /// `1`, the system default: low-priority I/O throttling is on.
    case throttleEnabled = "1"
    /// `0`, boost mode: low-priority I/O throttling is off.
    case throttleDisabled = "0"
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
        guard let value = ThrottleValue(rawValue: sysctlValue) else { return nil }
        self.init(value)
    }

    init(_ value: ThrottleValue) {
        switch value {
        case .throttleEnabled: self = .throttleEnabled
        case .throttleDisabled: self = .throttleDisabled
        }
    }

    /// The sysctl value this state corresponds to; `nil` for `.unknown`.
    var value: ThrottleValue? {
        switch self {
        case .throttleEnabled: return .throttleEnabled
        case .throttleDisabled: return .throttleDisabled
        case .unknown: return nil
        }
    }

    var sysctlValue: String? {
        value?.rawValue
    }

    /// `true` when boost mode is active, i.e. low-priority I/O throttling is disabled.
    var isBoostEnabled: Bool {
        self == .throttleDisabled
    }

    var isKnown: Bool {
        self != .unknown
    }
}
