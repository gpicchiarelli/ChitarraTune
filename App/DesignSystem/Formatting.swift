import Foundation
import TunerCore

/// A note split into the parts the big readout lays out separately.
struct NoteParts: Equatable {
    var letter: String
    var accidental: String
    var octave: String

    init(_ note: Note, notation: NoteNotation) {
        letter = notation == .english ? note.letter.english : note.letter.solfege
        accidental = note.accidental.symbol
        octave = String(note.octave)
    }

    var spoken: String { letter + accidental + octave }
}

extension Note {
    /// Label used in string chips, e.g. `E2` or `Mi♭2`.
    func chipLabel(_ notation: NoteNotation) -> String { label(notation: notation) }
}

extension TunerReading {
    /// Whole cents for display, with an explicit sign (`+3`, `−12`, `0`).
    var displayedCents: Int { Int(cents.rounded()) }
}

extension Int {
    /// Signed number using a true minus sign (U+2212), which reads better next to digits.
    var signedText: String {
        self == 0 ? "0" : (self > 0 ? "+\(self)" : "\u{2212}\(-self)")
    }
}

extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    static var frequency: FloatingPointFormatStyle<Double> { .number.precision(.fractionLength(1)) }
}
