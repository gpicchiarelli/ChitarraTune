import Foundation

/// One of the seven natural note letters.
public enum NoteLetter: Int, Sendable, Hashable, CaseIterable {
    case c, d, e, f, g, a, b

    /// English (Anglo-Saxon) name, e.g. `"E"`.
    public var english: String {
        switch self {
        case .c: "C"
        case .d: "D"
        case .e: "E"
        case .f: "F"
        case .g: "G"
        case .a: "A"
        case .b: "B"
        }
    }

    /// Fixed-do solfège name, e.g. `"Mi"`.
    public var solfege: String {
        switch self {
        case .c: "Do"
        case .d: "Re"
        case .e: "Mi"
        case .f: "Fa"
        case .g: "Sol"
        case .a: "La"
        case .b: "Si"
        }
    }
}

/// Accidental applied to a ``NoteLetter``.
public enum Accidental: Sendable, Hashable {
    case natural, sharp, flat

    /// Typographic symbol (empty for natural).
    public var symbol: String {
        switch self {
        case .natural: ""
        case .sharp: "♯"
        case .flat: "♭"
        }
    }
}

/// How note names are written.
public enum NoteNotation: String, Sendable, Hashable, CaseIterable, Codable {
    /// `C D E F G A B`
    case english
    /// `Do Re Mi Fa Sol La Si`
    case solfege
}

/// A pitch on the equal-tempered chromatic scale, identified by its MIDI number.
///
/// The `spelling` only affects how the note is *written* (`F♯3` vs `G♭3`); it never
/// changes the pitch.
public struct Note: Sendable, Hashable, Comparable {
    public enum Spelling: Sendable, Hashable {
        case sharps, flats
    }

    /// MIDI note number (A4 = 69).
    public let midi: Int
    public let spelling: Spelling

    public init(midi: Int, spelling: Spelling = .sharps) {
        self.midi = midi
        self.spelling = spelling
    }

    public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midi < rhs.midi }

    /// Scientific-pitch octave number (middle C = C4).
    public var octave: Int { Int((Double(midi) / 12).rounded(.down)) - 1 }

    /// Semitones above C, `0...11`.
    public var pitchClass: Int { ((midi % 12) + 12) % 12 }

    public var letter: NoteLetter {
        let table: [NoteLetter]
        switch spelling {
        case .sharps: table = [.c, .c, .d, .d, .e, .f, .f, .g, .g, .a, .a, .b]
        case .flats: table = [.c, .d, .d, .e, .e, .f, .g, .g, .a, .a, .b, .b]
        }
        return table[pitchClass]
    }

    public var accidental: Accidental {
        switch (pitchClass, spelling) {
        case (1, .sharps), (3, .sharps), (6, .sharps), (8, .sharps), (10, .sharps): .sharp
        case (1, .flats), (3, .flats), (6, .flats), (8, .flats), (10, .flats): .flat
        default: .natural
        }
    }

    /// Frequency in hertz for a given A4 reference (default 440 Hz).
    public func frequency(referenceA: Double = 440) -> Double {
        PitchMath.frequency(midi: midi, referenceA: referenceA)
    }

    /// Letter and accidental without the octave, e.g. `"F♯"` or `"Mi"`.
    public func name(notation: NoteNotation = .english) -> String {
        let base = notation == .english ? letter.english : letter.solfege
        return base + accidental.symbol
    }

    /// Full label including octave, e.g. `"F♯3"` or `"Mi2"`.
    public func label(notation: NoteNotation = .english) -> String {
        name(notation: notation) + String(octave)
    }

    /// The equal-tempered note closest to `frequency`, with the signed deviation in cents.
    public static func nearest(
        to frequency: Double,
        referenceA: Double = 440,
        spelling: Spelling = .sharps
    ) -> (note: Note, cents: Double)? {
        guard frequency.isFinite, frequency > 0, referenceA > 0 else { return nil }
        let exact = 69 + 12 * log2(frequency / referenceA)
        let midi = Int(exact.rounded())
        let note = Note(midi: midi, spelling: spelling)
        return (note, (exact - Double(midi)) * 100)
    }
}

/// Pure pitch arithmetic shared by the DSP and the presentation layers.
public enum PitchMath {
    public static let standardReferenceA: Double = 440

    /// Supported A4 calibration range (baroque 415 Hz … 466 Hz).
    public static let referenceARange: ClosedRange<Double> = 415...466

    /// Brings any stored or user-supplied A4 into ``referenceARange``.
    ///
    /// Infinite values clamp to the nearest bound. `NaN` (which survives `min`/`max` and would later
    /// build an invalid frequency range and trap) falls back to ``standardReferenceA``.
    public static func validReferenceA(_ value: Double) -> Double {
        guard !value.isNaN else { return standardReferenceA }
        return min(max(value, referenceARange.lowerBound), referenceARange.upperBound)
    }

    /// `referenceA · 2^((midi − 69) / 12)`
    public static func frequency(midi: Int, referenceA: Double = standardReferenceA) -> Double {
        referenceA * pow(2, Double(midi - 69) / 12)
    }

    /// Signed distance from `target` to `frequency` in cents (positive = sharp).
    public static func cents(from frequency: Double, to target: Double) -> Double {
        1200 * log2(frequency / target)
    }
}
