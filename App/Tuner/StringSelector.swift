import SwiftUI
import TunerCore
import TunerFeature

/// One glass chip per string. In automatic mode the detected string lights up; tapping a string pins
/// it (manual mode). ``AutoChip`` releases the pin again.
struct StringSelector: View {
    @Bindable var model: TunerModel
    let notation: NoteNotation

    private var state: TuneState { model.tuneState }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            strings
        }
    }

    /// One row of six at normal sizes, two rows of three at large sizes, a column at accessibility
    /// sizes: the labels always grow with Dynamic Type instead of shrinking to fit.
    @ViewBuilder
    private var strings: some View {
        let chips = Array(model.tuning.strings.enumerated())
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(chips, id: \.offset) { index, note in chip(index: index, note: note) }
            }
        } else if dynamicTypeSize >= .xxLarge {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: chips.count, by: 3)), id: \.self) { row in
                    GridRow {
                        ForEach(chips[row..<min(row + 3, chips.count)], id: \.offset) { index, note in
                            chip(index: index, note: note)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(chips, id: \.offset) { index, note in chip(index: index, note: note) }
            }
        }
    }

    private func chip(index: Int, note: Note) -> some View {
        let isPinned = model.target == .string(index)
        let isDetected = model.target == .automatic && model.detectedString == index
        let emphasised = isPinned || isDetected

        return Button {
            model.pinString(index)
        } label: {
            VStack(spacing: 2) {
                Text(note.chipLabel(notation))
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
                Text(verbatim: "\(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(emphasised ? Color.white : Color.tuneSecondaryLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        // Emphasised chips get an opaque fill under their white text: a tinted glass alone lets the
        // background through and white on it can fall below 4.5:1.
        .background {
            if let fill = fill(pinned: isPinned, detected: isDetected) {
                RoundedRectangle(cornerRadius: 16).fill(fill)
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .glassEffectID(index, in: glassNamespace)
        .foregroundStyle(emphasised ? Color.white : Color.primary)
        .overlay(alignment: .topTrailing) {
            if isDetected && state == .inTune {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, Color.tuneGreen)
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(note.chipLabel(notation)))
        .accessibilityValue(Text(.tunerString(index + 1)))
        .accessibilityHint(Text(.a11YPinHint))
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .accessibilityIdentifier("stringChip.\(index + 1)")
    }

    private func fill(pinned: Bool, detected: Bool) -> Color? {
        if pinned { return .tuneAccentFill }
        if detected { return state == .inTune ? .tuneGreenFill : .tuneAccentFill }
        return nil
    }
}

/// Toggle between automatic string detection and a pinned string.
struct AutoChip: View {
    let model: TunerModel

    var body: some View {
        let isAuto = model.target == .automatic
        Button {
            model.releaseString()
        } label: {
            Label(.tunerAuto, systemImage: "wand.and.sparkles")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background {
            if isAuto { Capsule().fill(Color.tuneAccentFill) }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .foregroundStyle(isAuto ? Color.white : Color.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.tunerAuto))
        .accessibilityAddTraits(isAuto ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Text(.a11YAutoHint))
        .accessibilityIdentifier("autoChip")
    }
}
