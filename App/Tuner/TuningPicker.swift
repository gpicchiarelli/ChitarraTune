import SwiftUI
import TunerCore
import TunerFeature

/// Menu listing every built-in tuning with a check mark on the current one.
struct TuningPicker: View {
    @Bindable var model: TunerModel
    let notation: NoteNotation

    var body: some View {
        #if os(macOS)
        // The Mac's own pop-up button: current tuning, check mark, keyboard and VoiceOver actions.
        Picker(selection: tuningBinding) {
            options
        } label: {
            Text(.tunerTuning)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(.tunerTuning))
        .accessibilityIdentifier("tuningPicker")
        #else
        menu
        #endif
    }

    private var options: some View {
        ForEach(Tuning.catalog) { tuning in
            Text("\(Text(tuning.id.title)) — \(tuning.stringSummary(notation))")
                .tag(tuning.id)
        }
    }

    /// iPhone and iPad: a glass capsule that opens the list of tunings.
    private var menu: some View {
        Menu {
            Picker(selection: tuningBinding) {
                options
            } label: {
                Text(.tunerTuning)
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Text(model.tuning.id.title)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.tuneSecondaryLabel)
            }
            .font(.subheadline)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(Text(.tunerTuning))
        .accessibilityValue(Text(model.tuning.id.title))
        .accessibilityIdentifier("tuningPicker")
    }

    private var tuningBinding: Binding<TuningID> {
        Binding(get: { model.tuning.id }, set: { model.tuning = .tuning(for: $0) })
    }
}
