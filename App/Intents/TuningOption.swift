import AppIntents
import TunerCore

/// Tunings offered to Siri and Shortcuts. The exhaustive switches make the compiler flag any
/// ``TuningID`` that is added without a matching case here.
enum TuningOption: String, AppEnum {
    case standard, halfDown, fullDown, dropD, dropC, dadgad, openD, openG, openE, openA

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("intent.tuning.type"))

    static let caseDisplayRepresentations: [TuningOption: DisplayRepresentation] = [
        .standard: DisplayRepresentation(title: LocalizedStringResource("tuning.standard"), subtitle: "E A D G B E"),
        .halfDown: DisplayRepresentation(title: LocalizedStringResource("tuning.halfDown"), subtitle: "E♭ A♭ D♭ G♭ B♭ E♭"),
        .fullDown: DisplayRepresentation(title: LocalizedStringResource("tuning.fullDown"), subtitle: "D G C F A D"),
        .dropD: DisplayRepresentation(title: LocalizedStringResource("tuning.dropD"), subtitle: "D A D G B E"),
        .dropC: DisplayRepresentation(title: LocalizedStringResource("tuning.dropC"), subtitle: "C G C F A D"),
        .dadgad: DisplayRepresentation(title: LocalizedStringResource("tuning.dadgad"), subtitle: "D A D G A D"),
        .openD: DisplayRepresentation(title: LocalizedStringResource("tuning.openD"), subtitle: "D A D F♯ A D"),
        .openG: DisplayRepresentation(title: LocalizedStringResource("tuning.openG"), subtitle: "D G D G B D"),
        .openE: DisplayRepresentation(title: LocalizedStringResource("tuning.openE"), subtitle: "E B E G♯ B E"),
        .openA: DisplayRepresentation(title: LocalizedStringResource("tuning.openA"), subtitle: "E A E A C♯ E"),
    ]

    var tuningID: TuningID {
        switch self {
        case .standard: .standard
        case .halfDown: .halfDown
        case .fullDown: .fullDown
        case .dropD: .dropD
        case .dropC: .dropC
        case .dadgad: .dadgad
        case .openD: .openD
        case .openG: .openG
        case .openE: .openE
        case .openA: .openA
        }
    }
}
