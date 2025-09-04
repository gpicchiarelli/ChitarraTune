import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var audio: AudioEngineManager
    @AppStorage("tuningPresetID") private var storedPresetID: String = "standard"
    @AppStorage("A4") private var storedA4: Double = 440
    @AppStorage("preferredInputUID") private var storedPreferredInputUID: String = ""
    @AppStorage("manualStringIndex") private var storedManualStringIndex: Int = 0
    @AppStorage("isAutoMode") private var storedIsAuto: Bool = true

    // Mirror available presets (static list is fine here)
    private let presets = DefaultTuningPresets

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "menu.settings"))
                .font(.headline)

            GroupBox(label: Label(String(localized: "controls.tuningPreset"), systemImage: "music.note.list")) {
                HStack {
                    Picker("", selection: $storedPresetID) {
                        ForEach(presets, id: \.id) { p in
                            Text(NSLocalizedString(p.nameKey, comment: "")).tag(p.id)
                        }
                    }
                    .labelsHidden()
                    Spacer()
                    Text(presets.first(where: { $0.id == storedPresetID }).map { NSLocalizedString($0.nameKey, comment: "") } ?? "")
                        .foregroundColor(.secondary)
                }
            }

            GroupBox(label: Label(String(localized: "controls.calibration"), systemImage: "gauge")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("A4")
                        Slider(value: $storedA4, in: 415...466, step: 1)
                        Text(storedA4, format: .number.precision(.fractionLength(0)))
                            .frame(width: 50, alignment: .trailing)
                        Text("units.hz")
                    }
                    HStack(spacing: 12) {
                        Text(String(localized: "controls.fine"))
                        Stepper("", value: Binding(
                            get: { Int((storedA4 * 10).rounded()) },
                            set: { storedA4 = Double($0) / 10.0 }
                        ), in: 4150...4660)
                        Text(storedA4, format: .number.precision(.fractionLength(1)))
                            .frame(width: 60, alignment: .trailing)
                        Button {
                            storedA4 = 440
                        } label: {
                            Label(String(localized: "controls.reset"), systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                }
            }

            GroupBox(label: Label(String(localized: "controls.audio"), systemImage: "speaker.wave.2.fill")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(String(localized: "controls.inputDevice"))
                        Spacer()
                        Button {
                            audio.refreshInputDevices()
                        } label: {
                            Label(String(localized: "controls.refreshDevices"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    Picker("", selection: Binding(
                        get: { audio.selectedInputUID ?? "" },
                        set: { newValue in
                            if newValue.isEmpty {
                                audio.setSystemDefaultInputDevice()
                            } else {
                                audio.setPreferredInputDevice(uid: newValue)
                            }
                            storedPreferredInputUID = newValue
                        }
                    )) {
                        Text("input.systemDefault").tag("")
                        ForEach(audio.availableInputDevices, id: \.id) { dev in
                            Text(dev.name).tag(dev.id)
                        }
                    }
                    .labelsHidden()
                    HStack {
                        Text(String(localized: "input.current")).foregroundColor(.secondary)
                        Spacer()
                        Text(audio.currentInputName.isEmpty ? String(localized: "input.systemDefault") : audio.currentInputName)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { audio.refreshInputDevices() }
    }
}
