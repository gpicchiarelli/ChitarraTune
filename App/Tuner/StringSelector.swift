import SwiftUI
import TunerCore
import TunerFeature

/// One glass chip per string. In automatic mode the detected string lights up; tapping a string pins
/// it (manual mode). ``AutoChip`` releases the pin again.
struct StringSelector: View {
    @Bindable var model: TunerModel
    let notation: NoteNotation
    let state: TuneState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            strings
        }
    }

    private var strings: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ForEach(Array(model.tuning.strings.enumerated()), id: \.offset) { index, note in
                chip(index: index, note: note)
            }
        }
    }

    private func chip(index: Int, note: Note) -> some View {
        let isPinned = model.target == .string(index)
        let isDetected = model.target == .automatic && model.highlightedString == index && model.reading != nil
        let emphasised = isPinned || isDetected

        return Button {
            model.pinString(index)
        } label: {
            VStack(spacing: 2) {
                Text(note.chipLabel(notation))
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: "\(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(emphasised ? Color.white.opacity(0.85) : Color.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .glassEffect(glass(pinned: isPinned, detected: isDetected), in: .rect(cornerRadius: 16))
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
    }

    private func glass(pinned: Bool, detected: Bool) -> Glass {
        if pinned { return .regular.tint(.accentColor).interactive() }
        if detected { return .regular.tint(state == .inTune ? .tuneGreen : .accentColor.opacity(0.7)).interactive() }
        return .regular.interactive()
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
        }
        .buttonStyle(.plain)
        .glassEffect(isAuto ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
        .foregroundStyle(isAuto ? Color.white : Color.primary)
        .accessibilityAddTraits(isAuto ? .isSelected : [])
        .accessibilityHint(Text(.a11YAutoHint))
        .accessibilityIdentifier("autoChip")
    }
}
