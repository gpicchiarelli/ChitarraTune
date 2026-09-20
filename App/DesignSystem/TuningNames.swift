import SwiftUI
import TunerCore

extension TuningID {
    var title: LocalizedStringResource {
        switch self {
        case .standard: .tuningStandard
        case .halfDown: .tuningHalfDown
        case .fullDown: .tuningFullDown
        case .dropD: .tuningDropD
        case .dropC: .tuningDropC
        case .dadgad: .tuningDadgad
        case .openD: .tuningOpenD
        case .openG: .tuningOpenG
        case .openE: .tuningOpenE
        case .openA: .tuningOpenA
        }
    }
}

extension Tuning {
    /// Strings written low → high, e.g. `E A D G B E`.
    func stringSummary(_ notation: NoteNotation) -> String {
        strings.map { $0.name(notation: notation) }.joined(separator: " ")
    }
}
