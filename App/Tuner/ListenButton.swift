import SwiftUI
import TunerFeature

/// The primary action. Large, prominent glass, reachable with the thumb; Space toggles it on Mac
/// and iPad keyboards.
struct ListenButton: View {
    let model: TunerModel

    var body: some View {
        Button {
            Task { await model.toggle() }
        } label: {
            Label {
                Text(model.isBusy ? .tunerStop : .tunerStart)
            } icon: {
                Image(systemName: model.isBusy ? "stop.fill" : "mic.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .tint(model.isBusy ? Color.tuneRed : Color.accentColor)
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityHint(Text(model.isBusy ? .a11YStopHint : .a11YStartHint))
        .accessibilityIdentifier("listenButton")
    }
}
