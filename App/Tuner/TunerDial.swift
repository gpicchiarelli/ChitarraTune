import SwiftUI

/// Analogue-style gauge: ±50 cents mapped onto a 124° arc, needle pivoting at the bottom.
///
/// The static face (arc, ticks, in-tune zone) is drawn once in a `Canvas` that depends only on its
/// geometry. The needle is a plain view rotated with `rotationEffect`, so each update animates on
/// the GPU and never re-runs the view body per frame.
struct TunerDial: View {
    let cents: Double?
    let state: TuneState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private static let range = 50.0
    private static let sweep = 62.0 // degrees on each side of vertical

    private var angle: Double {
        let clamped = min(max(cents ?? 0, -Self.range * 1.1), Self.range * 1.1)
        return clamped / Self.range * Self.sweep
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = min(size.width * 0.5 / sin(Self.sweep * .pi / 180) * 0.94, size.height * 0.92)
            let pivot = CGPoint(x: size.width / 2, y: size.height * 0.94)
            let needleLength = radius * 0.9
            let thickness = max(3, radius * 0.022)

            ZStack {
                DialFace(radius: radius, pivot: pivot, sweep: Self.sweep, range: Self.range, highContrast: contrast == .increased)

                ZStack {
                    Capsule()
                        .fill(cents == nil ? Color.secondary.opacity(0.35) : state.tint)
                        .frame(width: thickness, height: needleLength)
                        .offset(y: -needleLength / 2)
                }
                .frame(width: needleLength * 2, height: needleLength * 2)
                .rotationEffect(.degrees(angle))
                .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: angle)
                .position(pivot)

                Circle()
                    .fill(cents == nil ? Color.secondary.opacity(0.5) : state.tint)
                    .frame(width: thickness * 4, height: thickness * 4)
                    .position(pivot)
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .accessibilityHidden(true) // the parent exposes one combined element
    }
}

private struct DialFace: View {
    let radius: CGFloat
    let pivot: CGPoint
    let sweep: Double
    let range: Double
    let highContrast: Bool

    var body: some View {
        Canvas { context, _ in
            func point(_ cents: Double, _ r: CGFloat) -> CGPoint {
                let theta = cents / range * sweep * .pi / 180
                return CGPoint(x: pivot.x + r * sin(theta), y: pivot.y - r * cos(theta))
            }
            func arc(from: Double, to: Double, _ r: CGFloat) -> Path {
                var path = Path()
                let steps = max(2, Int(abs(to - from) / range * 64))
                for step in 0...steps {
                    let cents = from + (to - from) * Double(step) / Double(steps)
                    let p = point(cents, r)
                    if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                return path
            }

            let track = radius * 0.035
            // In-tune zone (±5 cents), then the full track.
            context.stroke(arc(from: -range, to: range, radius), with: .color(.secondary.opacity(highContrast ? 0.6 : 0.28)),
                           style: StrokeStyle(lineWidth: track, lineCap: .round))
            context.stroke(arc(from: -5, to: 5, radius), with: .color(.tuneGreen.opacity(highContrast ? 1 : 0.85)),
                           style: StrokeStyle(lineWidth: track * 2.2, lineCap: .round))

            // Ticks every 5 cents; longer every 10, longest at 0.
            for value in stride(from: -range, through: range, by: 5) {
                let major = value.truncatingRemainder(dividingBy: 10) == 0
                let isCentre = value == 0
                var tick = Path()
                tick.move(to: point(value, radius * (isCentre ? 0.80 : major ? 0.86 : 0.90)))
                tick.addLine(to: point(value, radius * 0.96))
                context.stroke(tick, with: .color(.primary.opacity(isCentre ? 0.9 : major ? 0.55 : 0.3)),
                               style: StrokeStyle(lineWidth: isCentre ? 2.5 : major ? 1.6 : 1, lineCap: .round))
            }
        }
    }
}

#Preview("Dial") {
    VStack(spacing: 24) {
        TunerDial(cents: nil, state: .idle)
        TunerDial(cents: -32, state: .flat(closeness: .far))
        TunerDial(cents: 9, state: .sharp(closeness: .close))
        TunerDial(cents: 1, state: .inTune)
    }
    .padding()
}
