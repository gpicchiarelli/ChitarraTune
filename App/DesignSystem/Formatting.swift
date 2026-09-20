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
}

extension Note {
    /// The note as VoiceOver should say it, e.g. "E flat, octave 2" / "Mi bemolle, ottava 2". A symbol
    /// such as ♭ would otherwise be left to the speech engine to guess, differently in every language.
    func spokenName(_ notation: NoteNotation) -> String {
        let name = notation == .english ? letter.english : letter.solfege
        switch accidental {
        case .natural: return String(localized: .a11YNoteNatural(name, octave))
        case .sharp: return String(localized: .a11YNoteSharp(name, octave))
        case .flat: return String(localized: .a11YNoteFlat(name, octave))
        }
    }
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
