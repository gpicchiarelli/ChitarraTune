import SwiftUI
import AppKit

// Helper target for NSButton link action
private let appLinkOpener = AppLinkOpener()
final class AppLinkOpener: NSObject {
    @objc func openWebsite(_ sender: Any?) {
        if let url = URL(string: "https://gpicchiarelli.github.io/ChitarraTune/") {
            NSWorkspace.shared.open(url)
        }
    }
}

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
        // Compose credits with version + optional RTF
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let header = NSMutableAttributedString(string: "Versione: \(display)\nSito: https://gpicchiarelli.github.io/ChitarraTune/\n\n", attributes: headerAttrs)
        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let credits = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            header.append(credits)
        }
        options[.credits] = header
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showLicensePanel() {
        // Prefer plain LICENSE text to avoid encoding artifacts; fallback to Credits.rtf
        let licenseAttrString: NSAttributedString? = {
            if let licURL = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
               let text = try? String(contentsOf: licURL, encoding: .utf8) {
                let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping; para.paragraphSpacing = 4
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: para
                ]
                return NSAttributedString(string: text, attributes: attrs)
            }
            if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
               let rtf = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return rtf
            }
            return nil
        }()

        guard let content = licenseAttrString else { showAboutPanel(); return }

        let size = NSSize(width: 640, height: 540)
        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: size))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 14)
        textView.textStorage?.setAttributedString(content)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let tc = textView.textContainer {
            tc.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
            tc.widthTracksTextView = true
        }
        scroll.documentView = textView

        // Header with app icon and website link
        let icon = NSApplication.shared.applicationIconImage
        let imageView = NSImageView(image: icon ?? NSImage())
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let linkButton = NSButton(title: "Sito Web", target: appLinkOpener, action: #selector(AppLinkOpener.openWebsite(_:)))
        linkButton.isBordered = false
        linkButton.contentTintColor = .linkColor
        linkButton.attributedTitle = NSAttributedString(string: "Sito Web", attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])

        let header = NSStackView(views: [imageView, linkButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let vStack = NSStackView(views: [header, scroll])
        vStack.orientation = .vertical
        vStack.alignment = .leading
        vStack.spacing = 12
        vStack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: NSSize(width: size.width + 28, height: size.height + 90)), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Licenza (BSD-3)"
        panel.contentView = vStack
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    // (link handled by AppLinkOpener)
}
