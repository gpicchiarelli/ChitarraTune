import Foundation
import Testing
@testable import TunerCore

@Suite("Tuning catalog")
struct TuningTests {
    @Test("Every identifier has exactly one catalog entry, in order")
    func catalogMatchesIdentifiers() {
        #expect(Tuning.catalog.map(\.id) == TuningID.allCases)
    }

    @Test("Strings are ordered low → high and there are six")
    func ordering() {
        for tuning in Tuning.catalog {
            #expect(tuning.stringCount == 6, "\(tuning.id)")
            #expect(tuning.strings == tuning.strings.sorted(), "\(tuning.id)")
        }
    }

    @Test("Well-known tunings spell correctly", arguments: [
        (TuningID.standard, ["E2", "A2", "D3", "G3", "B3", "E4"]),
        (.dropD, ["D2", "A2", "D3", "G3", "B3", "E4"]),
        (.dropC, ["C2", "G2", "C3", "F3", "A3", "D4"]),
        (.fullDown, ["D2", "G2", "C3", "F3", "A3", "D4"]),
        (.halfDown, ["E♭2", "A♭2", "D♭3", "G♭3", "B♭3", "E♭4"]),
        (.dadgad, ["D2", "A2", "D3", "G3", "A3", "D4"]),
        (.openD, ["D2", "A2", "D3", "F♯3", "A3", "D4"]),
        (.openG, ["D2", "G2", "D3", "G3", "B3", "D4"]),
        (.openE, ["E2", "B2", "E3", "G♯3", "B3", "E4"]),
        (.openA, ["E2", "A2", "E3", "A3", "C♯4", "E4"]),
    ])
    func spelling(id: TuningID, labels: [String]) {
        #expect(Tuning.tuning(for: id).strings.map { $0.label() } == labels)
    }

    @Test("Persisted raw identifiers keep working")
    func legacyIdentifiers() {
        // Values stored by previous releases in UserDefaults / App Intents.
        for raw in ["standard", "dropD", "dadgad", "openG", "openD", "halfDown"] {
            #expect(TuningID(rawValue: raw) != nil, "\(raw)")
        }
        #expect(Tuning.tuning(withRawID: "nonsense").id == .standard)
    }

    @Test("Detection range covers every string with head-room")
    func detectionRange() {
        for tuning in Tuning.catalog {
            let range = tuning.detectionRange()
            for note in tuning.strings {
                #expect(range.contains(note.frequency()), "\(tuning.id) \(note.label())")
            }
            #expect(range.lowerBound < tuning.strings[0].frequency())
        }
        // Regression: the old fixed 70 Hz floor excluded Drop C's 65.4 Hz string.
        #expect(Tuning.tuning(for: .dropC).detectionRange().lowerBound < 65.4)
    }

    @Test("Nearest string")
    func nearestString() {
        let standard = Tuning.standard
        let a = standard.nearestString(to: 110)
        #expect(a.index == 1)
        #expect(abs(a.cents) < 1e-9)

        let flatE = standard.nearestString(to: 82.4069 * pow(2, -30.0 / 1200))
        #expect(flatE.index == 0)
        #expect(abs(flatE.cents + 30) < 0.01)
    }
}
