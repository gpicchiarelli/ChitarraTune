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
                if let url = URL(string: "https://chitarratune.github.io") {
                    Link("Sito Web", destination: url)
                }
                if let lic = URL(string: "https://chitarratune.github.io/license.html") {
                    Link("Licenza (BSD-3)", destination: lic)
                }
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
        if let icon = NSImage(named: NSImage.applicationIconName) {
            options[.applicationIcon] = icon
        }
        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let credits = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            options[.credits] = credits
        }
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }
}
