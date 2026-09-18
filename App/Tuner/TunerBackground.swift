import SwiftUI
import TunerFeature

/// A soft radial wash that takes on the tuning state's colour. One cheap gradient, only re-rendered
/// when the state changes; it dims on Always-On displays and stays still with Reduce Motion.
struct TunerBackground: View {
    let state: TuneState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            RadialGradient(
                // Kept faint so secondary text on top of it keeps its contrast.
                colors: [wash.opacity(isLuminanceReduced ? 0.06 : 0.14), .clear],
                center: .init(x: 0.5, y: 0.22),
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: state)
        .accessibilityHidden(true)
    }

    private var wash: Color {
        state == .idle ? .accentColor.opacity(0.7) : state.tint
    }
}
