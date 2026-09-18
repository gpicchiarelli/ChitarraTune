import SwiftUI
import TunerCore
import TunerFeature

/// Menu listing every built-in tuning with a check mark on the current one.
struct TuningPicker: View {
    @Bindable var model: TunerModel
    let notation: NoteNotation

    var body: some View {
        Menu {
            Picker(selection: tuningBinding) {
                ForEach(Tuning.catalog) { tuning in
                    Text("\(Text(tuning.id.title)) — \(tuning.stringSummary(notation))")
                        .tag(tuning.id)
                }
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
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .lineLimit(1)
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
    }

    private var tuningBinding: Binding<TuningID> {
        Binding(get: { model.tuning.id }, set: { model.tuning = .tuning(for: $0) })
    }
}
