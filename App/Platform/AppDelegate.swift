#if os(macOS)
import AppKit
import os
import TunerAudio
import TunerFeature

/// Classic AppKit hooks that SwiftUI scenes don't expose.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App at launch; the Dock menu and termination act on it.
    static weak var hub: TunerHub?
    /// Opens the primary tuner window (provided by the menu commands, which own `openWindow`).
    static var openTunerWindow: (() -> Void)?

    /// Demo mode (UI tests, screenshots) brings itself forward: a test runner may launch it behind
    /// its own window, where synthesised clicks would land on something else.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if LaunchOptions.isDemo { NSApp.activate() }
    }

    /// Launched in the background (a login item, a test runner), AppKit opens no window and later
    /// activation does not open one either. Closing the last window quits the app, so "active with
    /// no window" only happens then: open the tuner, as a click on the Dock icon would.
    func applicationDidBecomeActive(_ notification: Notification) {
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        if !hasWindow { Self.openTunerWindow?() }
    }

    /// A tuner has no documents: closing its window means "I'm done".
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Longest a quit waits for the audio to stop. Core Audio can block while a device goes away
    /// (an interface unplugged mid-stop); ⌘Q must still quit.
    static let quitTimeout = Duration.seconds(2)

    /// Release the microphone before quitting (also covers ⌘Q while listening), but never wait longer
    /// than ``quitTimeout``: the system releases the device when the process exits anyway.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let hub = Self.hub else { return .terminateNow }
        let reply = QuitReply { sender.reply(toApplicationShouldTerminate: true) }
        Task {
            await hub.stopAll()
            reply.send()
        }
        Task {
            try? await Task.sleep(for: Self.quitTimeout)
            if reply.send() { TunerLog.app.error("audio did not stop within the quit timeout; quitting anyway") }
        }
        return .terminateLater
    }

    /// Right-click on the Dock icon: start/stop without bringing the window forward.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let model = Self.hub?.activeModel else { return nil }
        let title = String(localized: model.isBusy ? .menuStop : .menuStart)
        let item = NSMenuItem(title: title, action: #selector(toggleListening), keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: model.isBusy ? "stop.fill" : "mic.fill", accessibilityDescription: nil)
        let menu = NSMenu()
        menu.addItem(item)
        return menu
    }

    /// Longest a start waits for a just-requested window to actually appear.
    static let windowAppearanceTimeout = Duration.seconds(1)

    /// Starting from the Dock with no tuner window on screen opens one first: the microphone never
    /// runs for a tuner nobody can see.
    @objc private func toggleListening() {
        guard let hub = Self.hub else { return }
        let model = hub.activeModel
        guard !model.isBusy, !hub.hasVisibleTuner else {
            Task { await model.toggle() }
            return
        }
        Self.openTunerWindow?()
        // `openTunerWindow` only requests a window; SwiftUI creates it (and fires the `onAppear`/
        // `onChange` that tells the hub about it) on a later run-loop turn. Wait for that turn before
        // starting the microphone, or it could briefly run for a tuner still off screen.
        Task {
            guard await hub.waitForVisibleTuner(timeout: Self.windowAppearanceTimeout) else {
                TunerLog.app.error("no tuner window appeared; not starting the microphone")
                return
            }
            await model.toggle()
        }
    }
}

/// Answers AppKit's pending termination exactly once, whichever of "audio stopped" and "timeout"
/// comes first.
@MainActor
final class QuitReply {
    private var action: (() -> Void)?

    init(_ action: @escaping () -> Void) { self.action = action }

    /// Runs the reply if it has not run yet. Returns `true` if this call sent it.
    @discardableResult
    func send() -> Bool {
        guard let action else { return false }
        self.action = nil
        action()
        return true
    }
}
#endif
