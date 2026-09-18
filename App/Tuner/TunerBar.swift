import SwiftUI

/// Linear alternative to the dial: a horizontal track with a sliding indicator (±50 cents).
struct TunerBar: View {
    let cents: Double?
    let state: TuneState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private static let range = 50.0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let diameter = min(height * 0.62, 40)
            let travel = max(0, (width - diameter) / 2)
            let normalized = min(max((cents ?? 0) / Self.range, -1.1), 1.1)

            ZStack {
                BarFace(highContrast: contrast == .increased)

                Circle()
                    .fill(cents == nil ? Color.secondary.opacity(0.4) : state.tint)
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .frame(width: diameter, height: diameter)
                    .offset(x: normalized * travel)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: normalized)
            }
            .frame(width: width, height: height)
        }
        .frame(height: 76)
        .accessibilityHidden(true)
    }
}

private struct BarFace: View {
    let highContrast: Bool

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let inset: CGFloat = 20
            let usable = size.width - inset * 2
            func x(_ cents: Double) -> CGFloat { inset + usable * (cents + 50) / 100 }

            let track = CGRect(x: inset, y: midY - 5, width: usable, height: 10)
            context.fill(Path(roundedRect: track, cornerRadius: 5), with: .color(.secondary.opacity(highContrast ? 0.5 : 0.22)))
            let zone = CGRect(x: x(-5), y: midY - 5, width: x(5) - x(-5), height: 10)
            context.fill(Path(roundedRect: zone, cornerRadius: 5), with: .color(.tuneGreen.opacity(highContrast ? 1 : 0.8)))

            for value in stride(from: -50.0, through: 50.0, by: 10) {
                let isCentre = value == 0
                let half: CGFloat = isCentre ? 22 : 10
                var tick = Path()
                tick.move(to: CGPoint(x: x(value), y: midY - half - 6))
                tick.addLine(to: CGPoint(x: x(value), y: midY - 12))
                context.stroke(tick, with: .color(.primary.opacity(isCentre ? 0.9 : 0.4)),
                               style: StrokeStyle(lineWidth: isCentre ? 2.5 : 1.2, lineCap: .round))
            }
        }
    }
}

#Preview("Bar") {
    VStack {
        TunerBar(cents: nil, state: .idle)
        TunerBar(cents: 22, state: .sharp(closeness: .far))
        TunerBar(cents: 0, state: .inTune)
    }
    .padding()
}
