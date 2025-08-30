import SwiftUI
import ChitarraTuneCore

struct ContentView: View {
    @StateObject private var audio = AudioEngineManager()
    @State private var isAuto: Bool = true
    @State private var manualString: GuitarString = .e2
    @AppStorage("A4") private var storedA4: Double = 440
    @AppStorage("isAutoMode") private var storedIsAuto: Bool = true
    @AppStorage("manualStringName") private var storedManualStringName: String = "E2"

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
        .onAppear { audio.start() }
        .onDisappear { audio.stop() }
    }

    private var tunerView: some View {
        VStack(spacing: 24) {
            Text("app.title")
                .font(.title2).bold()

            if audio.isInTune {
                Text("status.inTune")
                    .foregroundColor(.green)
            }

            Text(audio.latestEstimate?.nearestString.name ?? "—")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            let cents = audio.latestEstimate?.cents ?? 0
            NeedleView(cents: cents)
                .frame(height: 140)

            HStack(spacing: 16) {
                let freq = audio.latestEstimate?.frequency ?? 0
                Text("\(freq, format: .number.precision(.fractionLength(2))) \(String(localized: \"units.hz\"))")
                if let c = audio.latestEstimate?.cents {
                    Text("\(c, format: .number.sign(strategy: .always).precision(.fractionLength(1))) \(String(localized: \"units.cents\"))")
                }
            }
            .font(.headline)
            .foregroundColor(.secondary)

            Divider()

            // Controls
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(audio.isRunning ? String(localized: "controls.stop") : String(localized: "controls.start")) {
                        audio.isRunning ? audio.stop() : audio.start()
                    }
                }

                Text("controls.mode").font(.headline)
                Picker("controls.mode", selection: $isAuto) {
                    Text("mode.auto").tag(true)
                    Text("mode.manual").tag(false)
                }
                .pickerStyle(.segmented)

                if !isAuto {
                    Text("controls.string").font(.headline)
                    Picker("controls.string", selection: $manualString) {
                        ForEach(GuitarString.allCases, id: \.self) { s in
                            Text(s.name).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Text("A4")
                    Slider(value: $audio.referenceA, in: 415...466, step: 1)
                    Text("\(audio.referenceA, format: .number.precision(.fractionLength(0))) \(String(localized: \"units.hz\"))")
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding()
        .onChange(of: isAuto) { newValue in
            audio.mode = newValue ? .auto : .manual(manualString)
            storedIsAuto = newValue
        }
        .onChange(of: manualString) { newValue in
            if !isAuto { audio.mode = .manual(newValue) }
            storedManualStringName = newValue.name
        }
        .onChange(of: audio.referenceA) { newValue in storedA4 = newValue }
        .onAppear {
            switch audio.mode {
            case .auto:
                isAuto = storedIsAuto
            case .manual(let s):
                isAuto = storedIsAuto
                manualString = s
            }
            audio.referenceA = storedA4
            if let restored = GuitarString.allCases.first(where: { $0.name == storedManualStringName }) {
                manualString = restored
                if !isAuto { audio.mode = .manual(restored) }
            }
        }
    }
}

struct NeedleView: View {
    let cents: Double // -50..+50 typical display

    private var clamped: Double {
        max(-100, min(100, cents))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let midX = width / 2
            let midY = height * 0.8

            ZStack {
                // Scale
                Path { path in
                    path.move(to: CGPoint(x: 16, y: midY))
                    path.addLine(to: CGPoint(x: width - 16, y: midY))
                }
                .stroke(Color.secondary.opacity(0.4), lineWidth: 3)

                // Center marker
                Path { path in
                    path.move(to: CGPoint(x: midX, y: midY - 20))
                    path.addLine(to: CGPoint(x: midX, y: midY + 20))
                }
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [4,4]))

                // Needle
                let normalized = clamped / 100.0 // -1..1
                let needleX = midX + CGFloat(normalized) * (width/2 - 24)
                Path { path in
                    path.move(to: CGPoint(x: midX, y: midY))
                    path.addLine(to: CGPoint(x: needleX, y: 24))
                }
                .stroke(color(for: clamped), lineWidth: 4)

                // Labels
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
