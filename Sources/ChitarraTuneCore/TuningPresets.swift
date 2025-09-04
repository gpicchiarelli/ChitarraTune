import Foundation

public struct NoteSpec: Sendable, Equatable {
    public let midi: Int
    public let label: String
    public init(midi: Int, label: String) {
        self.midi = midi
        self.label = label
    }
}

public struct TuningPreset: Sendable, Equatable, Identifiable {
    public let id: String
    public let nameKey: String // Localizable key
    public let strings: [NoteSpec] // Low -> High
    public init(id: String, nameKey: String, strings: [NoteSpec]) {
        self.id = id
        self.nameKey = nameKey
        self.strings = strings
    }
}

@inlinable
public func frequency(for midi: Int, referenceA: Double = 440.0) -> Double {
    return referenceA * pow(2.0, Double(midi - 69) / 12.0)
}

@inlinable
public func nearestString(in preset: TuningPreset, for frequencyHz: Double, referenceA: Double = 440.0) -> (index: Int, label: String, cents: Double) {
    var bestIndex = 0
    var bestValue = Double.infinity
    for (i, note) in preset.strings.enumerated() {
        let f = frequency(for: note.midi, referenceA: referenceA)
        let v = abs(log2(frequencyHz / f))
        if v < bestValue {
            bestValue = v
            bestIndex = i
        }
    }
    let targetF = frequency(for: preset.strings[bestIndex].midi, referenceA: referenceA)
    let cents = 1200.0 * log2(frequencyHz / targetF)
    return (bestIndex, preset.strings[bestIndex].label, cents)
}

public let DefaultTuningPresets: [TuningPreset] = {
    // Helper to build
    func n(_ midi: Int, _ label: String) -> NoteSpec { .init(midi: midi, label: label) }

    let standard = TuningPreset(
        id: "standard",
        nameKey: "tuning.standard",
        strings: [ n(40, "E2"), n(45, "A2"), n(50, "D3"), n(55, "G3"), n(59, "B3"), n(64, "E4") ]
    )
    let dropD = TuningPreset(
        id: "dropD",
        nameKey: "tuning.dropD",
        strings: [ n(38, "D2"), n(45, "A2"), n(50, "D3"), n(55, "G3"), n(59, "B3"), n(64, "E4") ]
    )
    let dadgad = TuningPreset(
        id: "dadgad",
        nameKey: "tuning.dadgad",
        strings: [ n(38, "D2"), n(45, "A2"), n(50, "D3"), n(55, "G3"), n(57, "A3"), n(62, "D4") ]
    )
    let openG = TuningPreset(
        id: "openG",
        nameKey: "tuning.openG",
        strings: [ n(38, "D2"), n(43, "G2"), n(50, "D3"), n(55, "G3"), n(59, "B3"), n(62, "D4") ]
    )
    let openD = TuningPreset(
        id: "openD",
        nameKey: "tuning.openD",
        strings: [ n(38, "D2"), n(45, "A2"), n(50, "D3"), n(54, "F#3"), n(57, "A3"), n(62, "D4") ]
    )
    let halfStepDown = TuningPreset(
        id: "halfDown",
        nameKey: "tuning.halfDown",
        strings: [ n(39, "Eb2"), n(44, "Ab2"), n(49, "Db3"), n(54, "Gb3"), n(58, "Bb3"), n(63, "Eb4") ]
    )
    return [standard, dropD, dadgad, openG, openD, halfStepDown]
}()

