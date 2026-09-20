import SwiftUI
import TunerAudio
import TunerFeature

/// Toolbar menu to pick the audio input (built-in mic, USB interface, headset…).
struct InputMenu: View {
    @Bindable var model: TunerModel

    var body: some View {
        #if os(macOS)
        // The Mac's pop-up button: the system shows the current input and the check mark, and
        // assistive tools get the standard press action.
        Picker(selection: selection) {
            options
        } label: {
            Text(.inputTitle)
        }
        .pickerStyle(.menu)
        .help(Text(.inputTitle))
        .accessibilityLabel(Text(.inputA11Y(model.activeInputName ?? String(localized: .inputMicrophone))))
        .accessibilityIdentifier("inputMenu")
        #else
        // iPhone and iPad: a toolbar menu whose button shows the input in use.
        Menu {
            Picker(selection: selection) {
                options
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
        #endif
    }

    @ViewBuilder
    private var options: some View {
        Text(.inputSystemDefault).tag(AudioInputSelection.systemDefault)
        ForEach(model.availableInputs) { device in
            Text(device.name).tag(AudioInputSelection.device(id: device.id))
        }
    }

    private var selection: Binding<AudioInputSelection> {
        Binding(
            get: { model.inputSelection },
            set: { newValue in Task { await model.selectInput(newValue) } }
        )
    }
}
