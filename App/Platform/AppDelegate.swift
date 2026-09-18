#if os(macOS)
import AppKit
import TunerFeature

/// Classic AppKit hooks that SwiftUI scenes don't expose.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App at launch; the Dock menu and termination act on it.
    static weak var hub: TunerHub?

    /// AppKit opens the first window only when the app is launched active. Demo mode (UI tests,
    /// screenshots) is often launched in the background by a test runner, so there it asks for
    /// the tuner window itself, exactly as a click on the Dock icon would.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard LaunchOptions.isDemo else { return }
        DispatchQueue.main.async {
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
        }
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
