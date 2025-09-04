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

        let size = NSSize(width: 600, height: 520)
        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: size))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.textStorage?.setAttributedString(credits)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let tc = textView.textContainer {
            tc.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
            tc.widthTracksTextView = true
        }
        scroll.documentView = textView

        let panel = NSPanel(contentRect: scroll.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Licenza (BSD-3)"
        panel.contentView = scroll
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
