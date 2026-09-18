import SwiftUI
import TunerFeature

/// Root view of one window/scene: looks up (or creates) the model for `id`, marks it active for
/// Siri and Shortcuts, and releases it when the window goes away.
struct TunerWindow: View {
    let hub: TunerHub
    let id: UUID

    var body: some View {
        let model = hub.model(for: id)
        NavigationStack {
            TunerScreen(model: model)
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 700)
        .containerBackground(.background, for: .window)
        #endif
        .onAppear { hub.activate(id) }
        .onDisappear { Task { await hub.discard(id) } }
    }
}
