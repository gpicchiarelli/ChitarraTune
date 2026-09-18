import SwiftUI
import TunerFeature

/// The primary action. Large, prominent glass, reachable with the thumb; Space toggles it on Mac
/// and iPad keyboards.
struct ListenButton: View {
    let model: TunerModel
    /// Starts listening. The screen decides whether to explain the microphone first.
    let start: () -> Void

    var body: some View {
        Button {
            if model.isBusy { Task { await model.stop() } } else { start() }
        } label: {
            Label {
                Text(model.isBusy ? .tunerStop : .tunerStart)
            } icon: {
                Image(systemName: model.isBusy ? "stop.fill" : "mic.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.prominentCapsule(fill: model.isBusy ? .tuneRedFill : .tuneAccentFill))
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityHint(Text(model.isBusy ? .a11YStopHint : .a11YStartHint))
        .accessibilityIdentifier("listenButton")
    }
}
