import SwiftUI
import TunerFeature

/// Root view of one window/scene: looks up (or creates) the model for `id`, marks it active for
/// Siri and Shortcuts, and releases it when the window is closed.
struct TunerWindow: View {
    let hub: TunerHub
    let id: UUID

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
        #endif
        .onAppear { hub.activate(id) }
        // Released when the window closes, not when it is hidden: switching tabs keeps its tuning and pin.
        .onWindowClose { Task { await hub.discard(id) } }
    }
}
