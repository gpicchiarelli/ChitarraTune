import SwiftUI

extension View {
    /// Runs `action` when the window that hosts this view is closed, and only then: not when the view
    /// merely leaves the screen (a hidden tab in a tabbed window, a minimised window).
    func onWindowClose(perform action: @escaping @MainActor () -> Void) -> some View {
        #if os(macOS)
        background(WindowCloseObserver(action: action))
        #else
        // iOS/iPadOS: one scene, whose model is the primary one and is never discarded.
        self
        #endif
    }
}

#if os(macOS)
import AppKit

private struct WindowCloseObserver: NSViewRepresentable {
    let action: @MainActor () -> Void

    func makeNSView(context: Context) -> Probe { Probe(action: action) }
    func updateNSView(_ probe: Probe, context: Context) { probe.action = action }

    /// A zero-size view that watches the window it is placed in.
    final class Probe: NSView {
        var action: @MainActor () -> Void
        private var observer: (any NSObjectProtocol)?

        init(action: @escaping @MainActor () -> Void) {
            self.action = action
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.action() }
            }
        }
    }
}
#endif
