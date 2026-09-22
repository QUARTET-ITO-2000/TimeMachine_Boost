import AppKit
import SwiftUI

/// Holds the window that hosts the log view.
///
/// `@State` cannot be used here: in the current SDK it is implemented as a macro and the
/// Command Line Tools toolchain ships no SwiftUI macro plugin, so a command-line build
/// fails with "plugin for module 'SwiftUIMacros' not found". A reference-type holder with
/// the classic `@StateObject` wrapper keeps `App/build.sh` working.
private final class HostWindow: ObservableObject {
    var window: NSWindow?
}

/// Live Time Machine log window.
struct LogView: View {
    @ObservedObject var manager: LogStreamManager
    @StateObject private var host = HostWindow()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(manager.status.message)
                .font(.callout)
                .foregroundStyle(manager.status.isError ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            logScrollView

            HStack(spacing: 8) {
                Button(L10n.t("log.clear")) {
                    manager.clear()
                }

                Spacer(minLength: 8)

                Button(L10n.t("log.stopAndHide")) {
                    stopAndHide()
                }
            }
        }
        .padding(12)
        .frame(minWidth: 480, minHeight: 320)
        .background(WindowAccessor { host.window = $0 })
        .onAppear {
            if !manager.isStreaming {
                manager.restart()
            }
        }
        .onDisappear {
            manager.stop()
        }
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(manager.entries) { entry in
                        Text(entry.text)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(6)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor))
            )
            .onChange(of: manager.entries.count) { _ in
                guard let last = manager.entries.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    /// Legacy "Stop and Hide": stop the stream and take the window away.
    private func stopAndHide() {
        manager.stop()
        // Close this window, not whatever happens to be the key window right now.
        (host.window ?? NSApp.keyWindow)?.performClose(nil)
    }
}
