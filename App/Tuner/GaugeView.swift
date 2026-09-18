import SwiftUI
import TunerCore
import TunerFeature

/// Dial or bar (per settings) with its ♭ / ♯ end labels and one combined accessibility element.
/// Reads the 40 Hz reading itself, so parents are not re-evaluated per frame.
struct GaugeView: View {
    let model: TunerModel

    var body: some View {
        let cents = model.reading?.cents
        let state = model.tuneState

        Group {
            switch model.settings.gaugeStyle {
            case .dial: TunerDial(cents: cents, state: state)
            case .bar: TunerBar(cents: cents, state: state)
            }
        }
        .frame(maxWidth: 520)
        .overlay(alignment: .bottom) {
            HStack {
                Text(.gaugeFlatEnd)
                Spacer()
                Text(.gaugeSharpEnd)
            }
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color.tuneSecondaryLabel)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(.gaugeLabel))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("tuningGauge")
    }

    private var accessibilityValue: String {
        guard let reading = model.reading else { return String(localized: .a11YNoSignal) }
        if reading.isInTune { return String(localized: .tunerStatusInTune) }
        let cents = abs(reading.displayedCents)
        return reading.cents < 0 ? String(localized: .a11YCentsFlat(cents)) : String(localized: .a11YCentsSharp(cents))
    }
}

/// Thin input-level bar. Purely visual (hidden from accessibility); shows the mic is hearing you.
struct LevelMeter: View {
    let model: TunerModel

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: proxy.size.width * model.inputLevel)
                        .animation(.linear(duration: 0.08), value: model.inputLevel)
                }
            }
            .frame(maxWidth: 220)
            .opacity(model.isListening ? 1 : 0.35)
            .accessibilityHidden(true)
    }
}
