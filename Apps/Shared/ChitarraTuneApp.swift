import SwiftUI
import AppKit

// Helper target for NSButton link action
private let appLinkOpener = AppLinkOpener()
private var aboutHelper: AboutHelper? = nil
final class AppLinkOpener: NSObject {
    @objc func openWebsite(_ sender: Any?) {
        if let url = URL(string: "https://gpicchiarelli.github.io/ChitarraTune/") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class AboutHelper: NSObject {
    let version: String
    init(version: String) { self.version = version }
    @objc func copyVersion(_ sender: Any?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(version, forType: .string)
    }
    @objc func openWebsite(_ sender: Any?) { appLinkOpener.openWebsite(sender) }
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
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "menu.settings")) { showPreferencesPanel() }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                if let url = URL(string: "https://gpicchiarelli.github.io/ChitarraTune/") {
                    Link("Sito Web", destination: url)
                }
                Button("Licenza (BSD-3)") { showLicensePanel() }
            }
        }
    }

    private func versionDisplay() -> String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let tag = BuildInfo.gitTag
        let commit = BuildInfo.gitCommit
        if !tag.isEmpty && !commit.isEmpty { return "\(tag) (\(commit))" }
        if !shortVersion.isEmpty && !commit.isEmpty { return "\(shortVersion) (\(commit))" }
        if !shortVersion.isEmpty && !build.isEmpty { return "\(shortVersion) (\(build))" }
        return shortVersion.isEmpty ? "Dev" : shortVersion
    }

    private func showAboutPanel() {
        let display = versionDisplay()

        // Build custom About panel (icon, name, version, actions)
        let icon = NSApplication.shared.applicationIconImage ?? NSImage()
        let imageView = NSImageView(image: icon)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let nameField = NSTextField(labelWithString: "ChitarraTune")
        nameField.font = .systemFont(ofSize: 20, weight: .semibold)
        let versionField = NSTextField(labelWithString: "Versione: \(display)")
        versionField.font = .systemFont(ofSize: 12)

        let infoStack = NSStackView(views: [nameField, versionField])
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 4

        let header = NSStackView(views: [imageView, infoStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14

        let copyBtn = NSButton(title: "Copia versione", target: nil, action: nil)
        let siteBtn = NSButton(title: "Sito Web", target: appLinkOpener, action: #selector(AppLinkOpener.openWebsite(_:)))
        copyBtn.bezelStyle = NSButton.BezelStyle.rounded
        siteBtn.bezelStyle = NSButton.BezelStyle.rounded
        aboutHelper = AboutHelper(version: display)
        copyBtn.target = aboutHelper
        copyBtn.action = #selector(AboutHelper.copyVersion(_:))

        let actions = NSStackView(views: [copyBtn, siteBtn])
        actions.orientation = .horizontal
        actions.spacing = 8

        let vStack = NSStackView(views: [header, actions])
        vStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        vStack.alignment = NSLayoutConstraint.Attribute.leading
        vStack.spacing = 12
        vStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 160), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Informazioni su ChitarraTune"
        panel.contentView = vStack
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func showLicensePanel() {
        // Prefer plain LICENSE text to avoid encoding artifacts; do not use RTF fallback
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
            return NSAttributedString(string: "LICENSE non trovato", attributes: [.font: NSFont.systemFont(ofSize: 12)])
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

        // Header with app icon and website link + version
        let icon = NSApplication.shared.applicationIconImage ?? NSImage()
        let imageView = NSImageView(image: icon)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let version = NSTextField(labelWithString: "Versione: \(versionDisplay())")
        version.font = NSFont.systemFont(ofSize: 12)
        let linkButton = NSButton(title: "Sito Web", target: appLinkOpener, action: #selector(AppLinkOpener.openWebsite(_:)))
        linkButton.bezelStyle = NSButton.BezelStyle.rounded

        let header = NSStackView(views: [imageView, version, linkButton])
        header.orientation = NSUserInterfaceLayoutOrientation.horizontal
        header.alignment = NSLayoutConstraint.Attribute.centerY
        header.spacing = 12

        let vStack = NSStackView(views: [header, scroll])
        vStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        vStack.alignment = NSLayoutConstraint.Attribute.leading
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

    private func showPreferencesPanel() {
        // Build a simple preferences window hosting SwiftUI PreferencesView
        let size = NSSize(width: 640, height: 520)
        let hosting = NSHostingView(rootView: PreferencesView())
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = String(localized: "menu.settings")
        panel.contentView = hosting
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
