import SwiftUI
import TunerAudio
import TunerFeature

/// Full-screen explanation when the microphone can't be used, with the one action that helps.
struct FailureView: View {
    let failure: CaptureFailure
    let model: TunerModel

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(failure.title)
            } icon: {
                Image(systemName: failure.symbol)
            }
        } description: {
            Text(failure.message)
        } actions: {
            if failure.needsSystemSettings {
                Button(.failureOpenSettings, action: PlatformSettings.openMicrophonePrivacy)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            if failure != .microphoneRestricted {
                Button(.failureRetry) { Task { await model.start() } }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
        }
        .accessibilityIdentifier("failureView")
    }
}
