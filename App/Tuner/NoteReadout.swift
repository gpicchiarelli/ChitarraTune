import SwiftUI
import TunerCore
import TunerFeature

/// The big note name with frequency and deviation underneath.
///
/// Reads the 40 Hz `reading` itself so that only this view (not its parents) is re-evaluated per frame.
struct NoteReadout: View {
    let model: TunerModel
    let note: Note?
    let notation: NoteNotation
    let hint: LocalizedStringResource

    private var reading: TunerReading? { model.reading }
    private var state: TuneState { model.tuneState }

    @ScaledMetric(relativeTo: .largeTitle) private var letterSize: CGFloat = 88
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDimmed: Bool { reading == nil || reading?.isHeld == true }

    var body: some View {
        VStack(spacing: 6) {
            noteName
                .frame(minHeight: letterSize * 0.98)

            statusLine
                .frame(minHeight: 26)

            numbers
                .frame(minHeight: 30)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(.a11YNote))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("noteReadout")
    }

    // MARK: Pieces

    @ViewBuilder
    private var noteName: some View {
        if let note {
            let parts = NoteParts(note, notation: notation)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(parts.letter)
                    .font(.system(size: letterSize, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 0) {
                    Text(parts.accidental)
                        .font(.system(size: letterSize * 0.42, weight: .semibold, design: .rounded))
                        .frame(height: letterSize * 0.42)
                    Text(parts.octave)
                        .font(.system(size: letterSize * 0.30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.tuneSecondaryLabel)
                }
                .offset(y: -letterSize * 0.28)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(state == .inTune ? Color.tuneGreen : .primary)
            .opacity(isDimmed ? 0.6 : 1)
            // Already 88 pt at the default size: capped so it always fits. Everything else scales.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } else {
            Text(verbatim: "—")
                .font(.system(size: letterSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tuneSecondaryLabel)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let title = state.title {
            Label {
                Text(title)
                if let advice = state.advice {
                    Text(advice).foregroundStyle(Color.tuneSecondaryLabel).font(.subheadline)
                }
            } icon: {
                Image(systemName: state.symbol)
            }
            .font(.headline)
            .foregroundStyle(state.tint)
            .labelStyle(.titleAndIcon)
            .opacity(reading?.isHeld == true ? 0.7 : 1)
        } else {
            Text(hint)
                .font(.subheadline)
                .foregroundStyle(Color.tuneSecondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var numbers: some View {
        if let reading {
            HStack(spacing: 20) {
                measurement(Text(reading.frequency, format: .frequency), unit: Text(.unitHz))
                measurement(Text(verbatim: reading.displayedCents.signedText), unit: Text(.unitCents), tint: state.tint)
            }
            .opacity(reading.isHeld ? 0.7 : 1)
        }
    }

    private func measurement(_ value: Text, unit: Text, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            value
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(reduceMotion ? .identity : .numericText())
            unit
                .font(.subheadline)
                .foregroundStyle(Color.tuneSecondaryLabel)
        }
    }

    private var accessibilityValue: String {
        guard let reading, let note else { return String(localized: .a11YNoSignal) }
        let spoken = NoteParts(note, notation: notation).spoken
        let cents = abs(reading.displayedCents)
        let deviation: String
        if reading.isInTune {
            deviation = String(localized: .a11YInTune(spoken))
        } else if reading.cents < 0 {
            deviation = String(localized: .a11YCentsFlat(cents))
        } else {
            deviation = String(localized: .a11YCentsSharp(cents))
        }
        return "\(spoken), \(deviation)"
    }
}
