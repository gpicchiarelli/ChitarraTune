import SwiftUI
import TunerCore
import TunerFeature

/// Menu-bar commands (macOS menu bar, iPadOS menu bar / keyboard shortcut overlay).
/// They act on the tuner of the focused window.
struct TunerCommands: Commands {
    let hub: TunerHub

    @FocusedValue(\.tuner) private var tuner
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Commands {
        #if os(macOS)
        // The commands exist as soon as the menu bar does, windows or not: hand AppKit a way to open
        // the tuner when the app becomes active without one (see AppDelegate).
        // swiftlint:disable:next redundant_discardable_let - a result builder accepts `let`, not `_ =`
        let _ = AppDelegate.openTunerWindow = { [openWindow, hub] in openWindow(id: "tuner", value: hub.primaryID) }
        CommandGroup(replacing: .appInfo) {
            Button(.menuAbout) { openWindow(id: "about") }
        }
        CommandGroup(replacing: .newItem) {
            Button(.menuNewWindow) { openWindow(id: "tuner", value: UUID()) }
                .keyboardShortcut("n")
        }
        CommandGroup(replacing: .help) {
            Button(.menuLicense) { openWindow(id: "license") }
            Link(destination: AboutView.repositoryURL.appending(path: "issues/new/choose")) {
                Text(.menuReportIssue)
            }
        }
        #endif

        CommandMenu(Text(.menuTuning)) {
            Button(tuner?.isBusy == true ? .menuStop : .menuStart) {
                guard let tuner else { return }
                Task { await tuner.toggle() }
            }
            .keyboardShortcut("l")
            .disabled(tuner == nil)

            Divider()

            Button(.menuAutomatic) { tuner?.releaseString() }
                .keyboardShortcut("0")
                .disabled(tuner == nil)

            ForEach(1...(tuner?.tuning.stringCount ?? Tuning.standard.stringCount), id: \.self) { number in
                Button(.menuString(number)) { tuner?.pinString(number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")))
                    .disabled(tuner == nil)
            }

            Divider()

            if let tuner {
                Picker(selection: Binding(get: { tuner.tuning.id }, set: { tuner.tuning = .tuning(for: $0) })) {
                    ForEach(Tuning.catalog) { tuning in
                        Text(tuning.id.title).tag(tuning.id)
                    }
                } label: {
                    Text(.tunerTuning)
                }
            }
        }
    }
}
