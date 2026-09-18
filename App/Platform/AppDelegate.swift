#if os(macOS)
import AppKit
import TunerFeature

/// Classic AppKit hooks that SwiftUI scenes don't expose.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App at launch; the Dock menu and termination act on it.
    static weak var hub: TunerHub?
    /// Opens the primary tuner window (provided by the menu commands, which own `openWindow`).
    static var openTunerWindow: (() -> Void)?

    /// Launched in the background (a login item, a test runner), AppKit opens no window and later
    /// activation does not open one either. Closing the last window quits the app, so "active with
    /// no window" only happens then: open the tuner, as a click on the Dock icon would.
    func applicationDidBecomeActive(_ notification: Notification) {
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        if !hasWindow { Self.openTunerWindow?() }
    }

    /// A tuner has no documents: closing its window means "I'm done".
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Release the microphone before quitting (also covers Cmd-Q while listening).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let hub = Self.hub else { return .terminateNow }
        Task {
            await hub.stopAll()
            sender.reply(toApplicationShouldTerminate: true)
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

    @objc private func toggleListening() {
        guard let model = Self.hub?.activeModel else { return }
        Task { await model.toggle() }
    }
}
#endif
