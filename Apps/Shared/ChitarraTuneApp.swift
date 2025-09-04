import SwiftUI
import AppKit

@main
struct ChitarraTuneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Informazioni su ChitarraTune") { showAboutPanel() }
            }
            CommandGroup(after: .help) {
                if let url = URL(string: "https://gpicchiarelli.github.io/ChitarraTune/") {
                    Link("Sito Web", destination: url)
                }
                Button("Licenza (BSD-3)") { showLicensePanel() }
            }
        }
    }

    private func showAboutPanel() {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let tag = BuildInfo.gitTag
        let commit = BuildInfo.gitCommit
        let display: String = {
            if !tag.isEmpty && !commit.isEmpty { return "\(tag) (\(commit))" }
            if !shortVersion.isEmpty && !commit.isEmpty { return "\(shortVersion) (\(commit))" }
            if !shortVersion.isEmpty && !build.isEmpty { return "\(shortVersion) (\(build))" }
            return shortVersion.isEmpty ? "Dev" : shortVersion
        }()

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "ChitarraTune",
            .applicationVersion: display,
        ]
        options[.applicationIcon] = NSApplication.shared.applicationIconImage
        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let credits = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            options[.credits] = credits
        }
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showLicensePanel() {
        guard let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
              let credits = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else {
            showAboutPanel(); return
        }
        let textView = NSTextView()
        textView.isEditable = false
        textView.textStorage?.setAttributedString(credits)
        textView.drawsBackground = false

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        scroll.documentView = textView
        scroll.hasVerticalScroller = true

        let panel = NSPanel(contentRect: scroll.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Licenza (BSD-3)"
        panel.contentView = scroll
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
