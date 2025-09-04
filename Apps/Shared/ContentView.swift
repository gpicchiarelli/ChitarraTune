import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audio: AudioEngineManager
    @State private var isAuto: Bool = true
    @State private var manualIndex: Int = 0
    @AppStorage("A4") private var storedA4: Double = 440
    @AppStorage("isAutoMode") private var storedIsAuto: Bool = true
    @AppStorage("manualStringIndex") private var storedManualStringIndex: Int = 0
    @AppStorage("tuningPresetID") private var storedPresetID: String = "standard"
    @AppStorage("preferredInputUID") private var storedPreferredInputUID: String = ""
    @State private var selectedInputUID: String = ""

    // MARK: - Derived State
    private var currentStringLabel: String {
        if isAuto { return audio.latestEstimate?.stringLabel ?? "—" }
        let idx = min(max(0, manualIndex), max(0, audio.preset.strings.count-1))
        return audio.preset.strings.isEmpty ? "—" : audio.preset.strings[idx].label
    }
    private var centsValue: Double { audio.latestEstimate?.cents ?? 0 }
    private var frequencyValue: Double { audio.latestEstimate?.frequency ?? 0 }
    private var targetFrequency: Double {
        guard !audio.preset.strings.isEmpty else { return 0 }
        if isAuto {
            if let idx = audio.latestEstimate?.stringIndex, idx >= 0, idx < audio.preset.strings.count {
                return frequency(for: audio.preset.strings[idx].midi, referenceA: audio.referenceA)
            }
            if let label = audio.latestEstimate?.stringLabel,
               let idx = audio.preset.strings.firstIndex(where: { $0.label == label }) {
                return frequency(for: audio.preset.strings[idx].midi, referenceA: audio.referenceA)
            }
        } else {
            let idx = min(max(0, manualIndex), max(0, audio.preset.strings.count-1))
            return frequency(for: audio.preset.strings[idx].midi, referenceA: audio.referenceA)
        }
        return 0
    }

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
            VStack(spacing: 12) {
                headerSection()
                titleSection()
                tuningBarSection()
                readoutSection()
                statusStripSection()
                weakSignalNotice()
            }
            .padding(12)
        }
        .frame(minWidth: 540, minHeight: 420)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    audio.isRunning ? audio.stop() : audio.start()
                } label: {
                    if audio.isRunning {
                        Label(String(localized: "controls.stop"), systemImage: "stop.fill")
                    } else {
                        Label(String(localized: "controls.start"), systemImage: "play.fill")
                    }
                }
                .accessibilityIdentifier("monitoringButton")

                Picker("controls.mode", selection: $isAuto) {
                    Text("mode.auto").tag(true)
                    Text("mode.manual").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("modePicker")

                if !isAuto {
                    Picker("controls.string", selection: $manualIndex) {
                        ForEach(0..<(audio.preset.strings.count), id: \.self) { idx in
                            let note = audio.preset.strings[idx]
                            Text(note.label).tag(idx)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stringPicker")
                    .labelsHidden()
                }
            }
        }
        .onChange(of: isAuto) { newValue in
            audio.mode = newValue ? .auto : .manual(manualIndex)
            storedIsAuto = newValue
        }
        .onChange(of: manualIndex) { newValue in
            if !isAuto { audio.mode = .manual(newValue) }
            storedManualStringIndex = newValue
        }
        .onChange(of: audio.referenceA) { newValue in storedA4 = newValue }
        .onChange(of: storedPresetID) { newID in
            applyPresetID(newID)
        }
        .onChange(of: audio.preset.id) { _ in
            // Ensure manual index is valid for the newly selected preset
            if manualIndex >= audio.preset.strings.count { manualIndex = 0 }
        }
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

// MARK: - Sections (split to help type checker)
private extension ContentView {
    func applyPresetID(_ id: String) {
        if let newPreset = audio.availablePresets.first(where: { $0.id == id }) {
            audio.preset = newPreset
            if manualIndex >= newPreset.strings.count { manualIndex = 0 }
        }
    }
    @ViewBuilder func headerSection() -> some View {
       /* Text("app.title")
            .font(.title2).bold()
            .accessibilityIdentifier("appTitleLabel", systemImage: "checkmark.circle.fill")
        */
        Image(systemName: "guitars").font(.system(size: 80))  
            .font(.largeTitle)
        if audio.isInTune {
            Label(String(localized: "status.inTune"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.green)
        }
    }

    @ViewBuilder func titleSection() -> some View {
        Text(currentStringLabel)
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        if targetFrequency > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(targetFrequency, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                Text("Hz").font(.title3).foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder func tuningBarSection() -> some View {
        TuningBarView(cents: centsValue)
            .frame(height: 96)
    }

    @ViewBuilder func readoutSection() -> some View {
        HStack(spacing: 16) {
            let absC = abs(centsValue)
            let tint: Color = absC < 5 ? .green : (absC < 15 ? .yellow : .red)
            Image(systemName: "circle.fill").foregroundColor(tint).font(.caption)
            Text(frequencyValue, format: .number.precision(.fractionLength(2)))
            Text("units.hz")
            if let c = audio.latestEstimate?.cents {
                Text(c, format: .number.sign(strategy: .always()).precision(.fractionLength(1)))
                Text("units.cents")
            }
        }
        .font(.headline)
        .foregroundColor(.secondary)
    }

    @ViewBuilder func statusStripSection() -> some View {
        HStack(spacing: 10) {
            Label(NSLocalizedString(audio.preset.nameKey, comment: ""), systemImage: "music.note.list")
            Divider()
            Label("A4 \(Int(audio.referenceA)) Hz", systemImage: "gauge")
            Divider()
            Label(audio.currentInputName.isEmpty ? String(localized: "input.systemDefault") : audio.currentInputName, systemImage: "mic")
            if let c = audio.latestEstimate?.cents {
                let absC = abs(c)
                let tint: Color = absC < 5 ? .green : (absC < 15 ? .yellow : .red)
                Text(String(format: "%+.1f", c))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.15)))
                    .foregroundColor(tint)
                    .accessibilityLabel("cents")
            }
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }

    @ViewBuilder func weakSignalNotice() -> some View {
        if audio.isSignalWeak {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("signal.weak")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder func controlsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Primary controls are in the toolbar to adhere to HIG
            // Leave only a minimal monitoring row here (optional)
            monitoringRow()
        }
    }

    @ViewBuilder func monitoringRow() -> some View {
        HStack {
            Button {
                audio.isRunning ? audio.stop() : audio.start()
            } label: {
                if audio.isRunning {
                    Label(String(localized: "controls.stop"), systemImage: "stop.fill")
                } else {
                    Label(String(localized: "controls.start"), systemImage: "play.fill")
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .tint(audio.isRunning ? .red : .accentColor)
            .accessibilityIdentifier("monitoringButton")
        }
    }

    @ViewBuilder func modeSection() -> some View {
        GroupBox(label: Label(String(localized: "controls.mode"), systemImage: "slider.horizontal.3")) {
            VStack(alignment: .leading) {
                Picker("controls.mode", selection: $isAuto) {
                    Label(String(localized: "mode.auto"), systemImage: "wand.and.stars").tag(true)
                    Label(String(localized: "mode.manual"), systemImage: "hand.point.up.left").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("modePicker")
                if !isAuto {
                    HStack {
                        Text("controls.string")
                        Spacer()
                        Picker("", selection: $manualIndex) {
                            ForEach(0..<(audio.preset.strings.count), id: \.self) { idx in
                                let note = audio.preset.strings[idx]
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
    }

    @ViewBuilder func tuningPresetSection() -> some View {
        GroupBox(label: Label(String(localized: "controls.tuningPreset"), systemImage: "music.note.list")) {
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
    }

    @ViewBuilder func calibrationSection() -> some View {
        GroupBox(label: Label(String(localized: "controls.calibration"), systemImage: "gauge")) {
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
                    Button {
                        audio.referenceA = 440
                    } label: {
                        Label(String(localized: "controls.reset"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder func audioSection() -> some View {
        GroupBox(label: Label(String(localized: "controls.audio"), systemImage: "speaker.wave.2.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("controls.inputDevice")
                    Spacer()
                    Button {
                        audio.refreshInputDevices()
                    } label: {
                        Label(String(localized: "controls.refreshDevices"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
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
