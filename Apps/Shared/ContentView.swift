import SwiftUI

struct ContentView: View {
    @StateObject private var audio = AudioEngineManager()
    @State private var isAuto: Bool = true
    @State private var manualIndex: Int = 0
    @AppStorage("A4") private var storedA4: Double = 440
    @AppStorage("isAutoMode") private var storedIsAuto: Bool = true
    @AppStorage("manualStringIndex") private var storedManualStringIndex: Int = 0
    @AppStorage("tuningPresetID") private var storedPresetID: String = "standard"
    @AppStorage("preferredInputUID") private var storedPreferredInputUID: String = ""
    @State private var selectedInputUID: String = ""

    var body: some View {
        Group {
            if audio.inputAvailable {
                tunerView
            } else {
                VStack(spacing: 12) {
                    Text("mic.unavailable")
                        .font(.title2).bold()
                    Text("mic.instructions")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .onAppear {
            let env = ProcessInfo.processInfo.environment
            if env["UITEST_DISABLE_AUDIO"] == "1" {
                // Skip starting audio engine during UI tests to avoid mic prompts
            } else {
                audio.start()
            }
        }
        .onDisappear { audio.stop() }
    }

    private var tunerView: some View {
        ScrollView {
        VStack(spacing: 24) {
            Text("app.title")
                .font(.title2).bold()
                .accessibilityIdentifier("appTitleLabel")

            if audio.isInTune {
                Text("status.inTune")
                    .foregroundColor(.green)
            }

            // Show selected string immediately in Manual mode; otherwise show detected
            let currentLabel: String = {
                if isAuto { return audio.latestEstimate?.stringLabel ?? "—" }
                let idx = min(max(0, manualIndex), max(0, audio.preset.strings.count-1))
                return audio.preset.strings.isEmpty ? "—" : audio.preset.strings[idx].label
            }()
            Text(currentLabel)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            let cents = audio.latestEstimate?.cents ?? 0
            TuningBarView(cents: cents)
                .frame(height: 120)

            HStack(spacing: 16) {
                let freq = audio.latestEstimate?.frequency ?? 0
                Text(freq, format: .number.precision(.fractionLength(2)))
                Text("units.hz")
                if let c = audio.latestEstimate?.cents {
                    Text(c, format: .number.sign(strategy: .always()).precision(.fractionLength(1)))
                    Text("units.cents")
                }
            }
            .font(.headline)
            .foregroundColor(.secondary)

            if audio.isSignalWeak {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("signal.weak")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Controls (macOS-style sections)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(audio.isRunning ? String(localized: "controls.stop") : String(localized: "controls.start")) {
                        audio.isRunning ? audio.stop() : audio.start()
                    }
                }

                
                GroupBox(String(localized: "controls.mode")) {
                    VStack(alignment: .leading) {
                        Picker("controls.mode", selection: $isAuto) {
                            Text("mode.auto").tag(true)
                            Text("mode.manual").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("modePicker")
                        if !isAuto {
                            HStack {
                                Text("controls.string")
                                Spacer()
                                Picker("", selection: $manualIndex) {
                                    ForEach(Array(audio.preset.strings.enumerated()), id: \.offset) { idx, note in
                                        Text(note.label).tag(idx)
                                    }
                                }
                                .labelsHidden()
                                .accessibilityLabel(Text("controls.string"))
                                .pickerStyle(.segmented)
                                .disabled(audio.preset.strings.isEmpty)
                            }
                        }
                    }
                }

                GroupBox(String(localized: "controls.tuningPreset")) {
                    HStack {
                        Picker("", selection: Binding(
                            get: { audio.preset.id },
                            set: { newID in
                                if let newPreset = audio.availablePresets.first(where: { $0.id == newID }) {
                                    audio.preset = newPreset
                                    if manualIndex >= newPreset.strings.count { manualIndex = 0 }
                                    storedPresetID = newID
                                }
                            }
                        )) {
                            ForEach(audio.availablePresets, id: \.id) { p in
                                Text(NSLocalizedString(p.nameKey, comment: "")).tag(p.id)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel(Text("controls.tuningPreset"))
                        .pickerStyle(.menu)
                        Spacer()
                        Text(NSLocalizedString(audio.preset.nameKey, comment: ""))
                            .foregroundColor(.secondary)
                    }
                }

                GroupBox(String(localized: "controls.calibration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("A4")
                            Slider(value: $audio.referenceA, in: 415...466, step: 1)
                            Text(audio.referenceA, format: .number.precision(.fractionLength(0)))
                                .frame(width: 50, alignment: .trailing)
                            Text("units.hz")
                        }
                        HStack(spacing: 12) {
                            Text("controls.fine")
                            Stepper("", value: Binding(
                                get: { Int((audio.referenceA * 10).rounded()) },
                                set: { audio.referenceA = Double($0) / 10.0 }
                            ), in: 4150...4660)
                            Text(audio.referenceA, format: .number.precision(.fractionLength(1)))
                                .frame(width: 60, alignment: .trailing)
                            Button(String(localized: "controls.reset")) { audio.referenceA = 440 }
                        }
                    }
                }

                GroupBox(String(localized: "controls.audio")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("controls.inputDevice")
                            Spacer()
                            Button(String(localized: "controls.refreshDevices")) { audio.refreshInputDevices() }
                        }
                        Picker("", selection: $selectedInputUID) {
                            Text("input.systemDefault").tag("")
                            ForEach(audio.availableInputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel(Text("controls.inputDevice"))
                        .pickerStyle(.menu)
                        HStack {
                            Text("input.current").foregroundColor(.secondary)
                            Spacer()
                            Text(audio.currentInputName.isEmpty ? String(localized: "input.systemDefault") : audio.currentInputName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        }
        .frame(minWidth: 720, minHeight: 720)
        .onChange(of: isAuto) { newValue in
            audio.mode = newValue ? .auto : .manual(manualIndex)
            storedIsAuto = newValue
        }
        .onChange(of: manualIndex) { newValue in
            if !isAuto { audio.mode = .manual(newValue) }
            storedManualStringIndex = newValue
        }
        .onChange(of: audio.referenceA) { newValue in storedA4 = newValue }
        .onChange(of: selectedInputUID) { newValue in
            if newValue.isEmpty {
                audio.setSystemDefaultInputDevice()
            } else {
                audio.setPreferredInputDevice(uid: newValue)
            }
            storedPreferredInputUID = newValue
        }
        .onChange(of: audio.availableInputDevices) { _ in
            if !selectedInputUID.isEmpty {
                audio.setPreferredInputDevice(uid: selectedInputUID)
            }
        }
        .onAppear {
            switch audio.mode {
            case .auto:
                isAuto = storedIsAuto
            case .manual(let s):
                isAuto = storedIsAuto
                manualIndex = s
            }
            audio.referenceA = storedA4
            // Restore preset and manual index
            if let restored = audio.availablePresets.first(where: { $0.id == storedPresetID }) {
                audio.preset = restored
            }
            manualIndex = storedManualStringIndex
            if !isAuto { audio.mode = .manual(manualIndex) }
            audio.refreshInputDevices()
            selectedInputUID = storedPreferredInputUID
            if selectedInputUID.isEmpty {
                // use system default implicitly
            } else {
                audio.setPreferredInputDevice(uid: selectedInputUID)
            }
        }
    }
}

// MARK: - Alternative Bar View

struct TuningBarView: View {
    let cents: Double // -100..+100 typical

    private var clamped: Double { max(-100, min(100, cents)) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let midX = width / 2

            ZStack {
                // Base track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: height * 0.35)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Green in-tune zone (±5 cents)
                let zoneWidth = width * 0.10 // ~10% width
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.25))
                    .frame(width: zoneWidth, height: height * 0.35)
                    .position(x: midX, y: height/2)

                // Tick marks (-50, -25, 0, +25, +50)
                let ticks: [Double] = [-50, -25, 0, 25, 50]
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, t in
                    let x = midX + CGFloat(t/100) * (width/2 - 12)
                    Path { p in
                        p.move(to: CGPoint(x: x, y: height*0.25))
                        p.addLine(to: CGPoint(x: x, y: height*0.75))
                    }
                    .stroke(t == 0 ? Color.secondary : Color.secondary.opacity(0.6), lineWidth: t == 0 ? 2 : 1)
                }

                // Moving indicator
                let normalized = clamped / 100.0 // -1..1
                let indicatorX = midX + CGFloat(normalized) * (width/2 - 12)
                Capsule()
                    .fill(color(for: clamped))
                    .frame(width: 6, height: height * 0.6)
                    .position(x: indicatorX, y: height/2)

                // Edge labels
                HStack {
                    Text("tuning.low").font(.caption)
                    Spacer()
                    Text("tuning.high").font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private func color(for cents: Double) -> Color {
        let absC = abs(cents)
        if absC < 5 { return .green }
        if absC < 15 { return .yellow }
        return .red
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.sizeThatFits)
    }
}
#endif
