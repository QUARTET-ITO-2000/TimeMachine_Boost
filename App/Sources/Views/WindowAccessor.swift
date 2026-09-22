import AppKit
import SwiftUI

/// Reports the `NSWindow` that hosts a SwiftUI view.
/// Used to close exactly that window instead of relying on the current key window.
struct WindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        report(from: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        report(from: nsView, coordinator: context.coordinator)
    }

    /// The view is inserted into the hierarchy during `makeNSView`, but the window is
    /// attached a moment later, so the lookup is deferred by one main-runloop turn.
    private func report(from view: NSView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard coordinator.lastWindow !== view.window else { return }
            coordinator.lastWindow = view.window
            onWindowChange(view.window)
        }
    }

    final class Coordinator {
        weak var lastWindow: NSWindow?
    }
}
