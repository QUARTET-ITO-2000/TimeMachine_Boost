import AppKit

/// Speaks important state changes through the assistive application.
///
/// Text that changes inside the window is not read out on its own, so operations that
/// finish while the user is looking elsewhere (a verified boost change, a cancelled
/// authorization, a failed operation) are announced explicitly. macOS 13 ships no
/// SwiftUI announcement API, so this bridges to the AppKit notification. Posting has
/// no effect while VoiceOver is off.
enum AccessibilityAnnouncement {
    static func post(_ message: String, priority: NSAccessibilityPriorityLevel = .medium) {
        guard !message.isEmpty, NSWorkspace.shared.isVoiceOverEnabled else { return }

        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            .announcement: message,
            .priority: NSNumber(value: priority.rawValue)
        ]

        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: userInfo
        )
    }
}
