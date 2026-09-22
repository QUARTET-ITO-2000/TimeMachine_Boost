import AppKit
import SwiftUI

@main
struct TimeMachineBoostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Time Machine Boost", id: WindowID.main) {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            // Keep the localized application menu entries of the legacy GUI.
            CommandGroup(replacing: .appInfo) {
                Button(L10n.t("menu.about")) {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button(L10n.t("menu.quit")) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }

        Window(L10n.t("log.windowTitle"), id: WindowID.logs) {
            LogView(manager: LogStreamManager.shared)
        }
        .defaultSize(width: 760, height: 500)
        .windowResizability(.contentMinSize)
    }
}
