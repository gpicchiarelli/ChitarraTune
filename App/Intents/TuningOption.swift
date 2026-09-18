import AppIntents
import TunerCore

/// Tunings offered to Siri and Shortcuts. The exhaustive switches make the compiler flag any
/// ``TuningID`` that is added without a matching case here.
///
/// It mirrors ``TuningID`` instead of conforming it to `AppEnum` because the App Intents metadata
/// extractor needs `caseDisplayRepresentations` as a literal in the app target. The subtitles are
/// localized (solfège in Italian); `AppStoreMetadataTests`/`LocalizationTests` check them against the
/// tuning catalog.
enum TuningOption: String, AppEnum {
    case standard, halfDown, fullDown, dropD, dropC, dadgad, openD, openG, openE, openA

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("intent.tuning.type"))

    static let caseDisplayRepresentations: [TuningOption: DisplayRepresentation] = [
        .standard: DisplayRepresentation(title: LocalizedStringResource("tuning.standard"), subtitle: LocalizedStringResource("tuning.standard.strings")),
        .halfDown: DisplayRepresentation(title: LocalizedStringResource("tuning.halfDown"), subtitle: LocalizedStringResource("tuning.halfDown.strings")),
        .fullDown: DisplayRepresentation(title: LocalizedStringResource("tuning.fullDown"), subtitle: LocalizedStringResource("tuning.fullDown.strings")),
        .dropD: DisplayRepresentation(title: LocalizedStringResource("tuning.dropD"), subtitle: LocalizedStringResource("tuning.dropD.strings")),
        .dropC: DisplayRepresentation(title: LocalizedStringResource("tuning.dropC"), subtitle: LocalizedStringResource("tuning.dropC.strings")),
        .dadgad: DisplayRepresentation(title: LocalizedStringResource("tuning.dadgad"), subtitle: LocalizedStringResource("tuning.dadgad.strings")),
        .openD: DisplayRepresentation(title: LocalizedStringResource("tuning.openD"), subtitle: LocalizedStringResource("tuning.openD.strings")),
        .openG: DisplayRepresentation(title: LocalizedStringResource("tuning.openG"), subtitle: LocalizedStringResource("tuning.openG.strings")),
        .openE: DisplayRepresentation(title: LocalizedStringResource("tuning.openE"), subtitle: LocalizedStringResource("tuning.openE.strings")),
        .openA: DisplayRepresentation(title: LocalizedStringResource("tuning.openA"), subtitle: LocalizedStringResource("tuning.openA.strings")),
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
