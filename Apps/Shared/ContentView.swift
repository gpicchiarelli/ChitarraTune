import SwiftUI
import ChitarraTuneCore

struct ContentView: View {
    @StateObject private var audio = AudioEngineManager()

    var body: some View {
        Group {
#if os(tvOS)
            if !audio.inputAvailable {
                VStack(spacing: 16) {
                    Text("ChitarraTune")
                        .font(.largeTitle).bold()
                    Text("tvOS non supporta l'ingresso microfono.")
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                tunerView
            }
#else
            if audio.inputAvailable {
                tunerView
            } else {
                VStack(spacing: 12) {
                    Text("Microfono non disponibile")
                        .font(.title2).bold()
                    Text("Concedi l'accesso al microfono nelle Impostazioni.")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
#endif
        }
        .onAppear { audio.start() }
        .onDisappear { audio.stop() }
    }

    private var tunerView: some View {
        VStack(spacing: 24) {
            Text("ChitarraTune")
                .font(.title2).bold()

            Text(audio.latestEstimate?.nearestString.name ?? "—")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            let cents = audio.latestEstimate?.cents ?? 0
            NeedleView(cents: cents)
                .frame(height: 120)

            HStack(spacing: 16) {
                Text(String(format: "%.2f Hz", audio.latestEstimate?.frequency ?? 0))
                if let c = audio.latestEstimate?.cents {
                    Text(String(format: "%+.1f cents", c))
                }
            }
            .font(.headline)
            .foregroundColor(.secondary)
        }
        .padding()
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
                    Text("basso").font(.caption)
                    Spacer()
                    Text("alto").font(.caption)
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

