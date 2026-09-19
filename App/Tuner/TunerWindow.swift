import SwiftUI
import TunerFeature

/// Root view of one window/scene: looks up (or creates) the model for `id`, tells the hub when the
/// window is shown, focused and closed (Siri, Shortcuts and the Dock menu act on the focused one),
/// and releases the model when the window is closed.
struct TunerWindow: View {
    let hub: TunerHub
    let id: UUID

    #if os(macOS)
    /// `true` while this is the key window of the active app.
    @Environment(\.appearsActive) private var appearsActive
    #endif

    var body: some View {
        let model = hub.model(for: id)
        NavigationStack {
            TunerScreen(model: model)
        }
        #if os(macOS)
        // Small enough for a 1024 × 768 display with the menu bar and Dock; the content scrolls when
        // the window is shorter than it.
        .frame(minWidth: 420, minHeight: 520)
        .containerBackground(.background, for: .window)
        .onChange(of: appearsActive, initial: true) { _, active in
            if active { hub.activate(id) } else { hub.windowAppeared(id) }
        }
        #else
        .onAppear { hub.activate(id) }
        #endif
        // Released when the window closes, not when it is hidden: switching tabs keeps its tuning and pin.
        .onWindowClose { Task { await hub.discard(id) } }
    }
}
