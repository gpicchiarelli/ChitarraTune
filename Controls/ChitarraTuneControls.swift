import AppIntents
import SwiftUI
import WidgetKit

/// The Controls extension: system controls that start the tuner from outside the app.
@main
struct ChitarraTuneControls: WidgetBundle {
    var body: some Widget {
        StartTuningControl()
    }
}

/// "Start Tuning" for Control Center, the Lock Screen and the Action Button (iPhone, iPad) and
/// Control Center and the menu bar (Mac). Tapping it opens ChitarraTune and starts listening.
struct StartTuningControl: ControlWidget {
    static let kind = "com.chitarratune.app.control.start-tuning"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartTuningIntent()) {
                Label {
                    Text(LocalizedStringResource("control.start.title"))
                } icon: {
                    Image(systemName: "tuningfork")
                }
            }
        }
        .displayName(LocalizedStringResource("control.start.title"))
        .description(LocalizedStringResource("control.start.description"))
    }
}
