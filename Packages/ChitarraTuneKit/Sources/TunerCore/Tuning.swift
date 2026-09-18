import Foundation

/// Stable identifier of a built-in tuning. Raw values are persisted in user defaults and
/// used by App Intents, so they must never change.
public enum TuningID: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    case standard
    case halfDown
    case fullDown
    case dropD
    case dropC
    case dadgad
    case openD
    case openG
    case openE
    case openA

    public var id: String { rawValue }
}

/// A named set of open-string pitches, ordered from the lowest string to the highest.
public struct Tuning: Sendable, Hashable, Identifiable {
    public let id: TuningID
    /// Open-string notes, lowest string first.
    public let strings: [Note]

    public init(id: TuningID, strings: [Note]) {
        precondition(!strings.isEmpty, "A tuning needs at least one string")
        self.id = id
        self.strings = strings
    }

    public var stringCount: Int { strings.count }

    /// Frequency range a detector must cover to hear every string of this tuning
    /// (with head-room for strings that are far out of tune).
    public func detectionRange(referenceA: Double = PitchMath.standardReferenceA) -> ClosedRange<Double> {
        let low = strings.map { $0.frequency(referenceA: referenceA) }.min() ?? 80
        let high = strings.map { $0.frequency(referenceA: referenceA) }.max() ?? 330
        return (low * 0.8)...(high * 1.5)
    }

    /// The string whose pitch is closest (on a logarithmic scale) to `frequency`.
    public func nearestString(
        to frequency: Double,
        referenceA: Double = PitchMath.standardReferenceA
    ) -> (index: Int, cents: Double) {
        var best = (index: 0, cents: Double.infinity)
        for (index, note) in strings.enumerated() {
            let cents = PitchMath.cents(from: frequency, to: note.frequency(referenceA: referenceA))
            if abs(cents) < abs(best.cents) { best = (index, cents) }
        }
        return best
    }
}

// MARK: - Catalog

extension Tuning {
    /// All built-in tunings, in presentation order.
    public static let catalog: [Tuning] = TuningID.allCases.map(Tuning.make(_:))

    public static let standard = make(.standard)

    /// Looks up a built-in tuning; falls back to standard tuning for unknown identifiers.
    public static func tuning(withRawID rawID: String) -> Tuning {
        TuningID(rawValue: rawID).map(make(_:)) ?? standard
    }

    public static func tuning(for id: TuningID) -> Tuning { make(id) }

    private static func make(_ id: TuningID) -> Tuning {
        func sharps(_ midis: [Int]) -> [Note] { midis.map { Note(midi: $0, spelling: .sharps) } }
        func flats(_ midis: [Int]) -> [Note] { midis.map { Note(midi: $0, spelling: .flats) } }

        switch id {
        case .standard: return Tuning(id: id, strings: sharps([40, 45, 50, 55, 59, 64])) // E A D G B E
        case .halfDown: return Tuning(id: id, strings: flats([39, 44, 49, 54, 58, 63]))  // E♭ A♭ D♭ G♭ B♭ E♭
        case .fullDown: return Tuning(id: id, strings: sharps([38, 43, 48, 53, 57, 62])) // D G C F A D
        case .dropD: return Tuning(id: id, strings: sharps([38, 45, 50, 55, 59, 64]))    // D A D G B E
        case .dropC: return Tuning(id: id, strings: sharps([36, 43, 48, 53, 57, 62]))    // C G C F A D
        case .dadgad: return Tuning(id: id, strings: sharps([38, 45, 50, 55, 57, 62]))   // D A D G A D
        case .openD: return Tuning(id: id, strings: sharps([38, 45, 50, 54, 57, 62]))    // D A D F♯ A D
        case .openG: return Tuning(id: id, strings: sharps([38, 43, 50, 55, 59, 62]))    // D G D G B D
        case .openE: return Tuning(id: id, strings: sharps([40, 47, 52, 56, 59, 64]))    // E B E G♯ B E
        case .openA: return Tuning(id: id, strings: sharps([40, 45, 52, 57, 61, 64]))    // E A E A C♯ E
        }
    }
}
