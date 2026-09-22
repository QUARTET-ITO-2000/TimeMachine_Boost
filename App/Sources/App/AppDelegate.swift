import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The legacy GUI quit when its last window was closed; keep that behaviour.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Never leave a `log stream` process behind.
    func applicationWillTerminate(_ notification: Notification) {
        LogStreamManager.shared.stop()
    }
}
