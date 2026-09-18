import SwiftUI
import TunerAudio
import TunerFeature

/// Toolbar menu to pick the audio input (built-in mic, USB interface, headset…).
struct InputMenu: View {
    @Bindable var model: TunerModel

    var body: some View {
        Menu {
            Picker(selection: selection) {
                Text(.inputSystemDefault).tag(AudioInputSelection.systemDefault)
                ForEach(model.availableInputs) { device in
                    Text(device.name).tag(AudioInputSelection.device(id: device.id))
                }
            } label: {
                Text(.inputTitle)
            }
            .pickerStyle(.inline)
        } label: {
            Label {
                Text(model.activeInputName ?? String(localized: .inputMicrophone))
            } icon: {
                Image(systemName: "mic.fill")
            }
        }
        .accessibilityLabel(Text(.inputA11Y(model.activeInputName ?? String(localized: .inputMicrophone))))
        .accessibilityIdentifier("inputMenu")
    }

    private var selection: Binding<AudioInputSelection> {
        Binding(
            get: { model.inputSelection },
            set: { newValue in Task { await model.selectInput(newValue) } }
        )
    }
}
