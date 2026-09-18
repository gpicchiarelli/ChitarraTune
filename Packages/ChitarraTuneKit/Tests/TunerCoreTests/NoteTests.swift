import Foundation
import Testing
@testable import TunerCore

@Suite("Note")
struct NoteTests {
    @Test("A4 is 440 Hz and scales with the reference")
    func referencePitch() {
        #expect(Note(midi: 69).frequency() == 440)
        #expect(abs(Note(midi: 69).frequency(referenceA: 432) - 432) < 1e-9)
    }

    @Test("Guitar open strings in standard tuning", arguments: [
        (40, 82.4069), (45, 110.0), (50, 146.8324), (55, 195.9977), (59, 246.9417), (64, 329.6276),
    ])
    func openStrings(midi: Int, expected: Double) {
        #expect(abs(Note(midi: midi).frequency() - expected) < 0.001)
    }

    @Test("Octave numbering follows scientific pitch notation", arguments: [
        (60, 4), (69, 4), (40, 2), (36, 2), (35, 1), (12, 0), (11, -1),
    ])
    func octaves(midi: Int, octave: Int) {
        #expect(Note(midi: midi).octave == octave)
    }

    @Test("Sharp and flat spellings share the same pitch")
    func spelling() {
        let sharp = Note(midi: 54, spelling: .sharps)
        let flat = Note(midi: 54, spelling: .flats)
        #expect(sharp.label() == "F♯3")
        #expect(flat.label() == "G♭3")
        #expect(sharp.frequency() == flat.frequency())
    }

    @Test("Natural notes have no accidental")
    func naturals() {
        for midi in [60, 62, 64, 65, 67, 69, 71] {
            #expect(Note(midi: midi, spelling: .sharps).accidental == .natural)
            #expect(Note(midi: midi, spelling: .flats).accidental == .natural)
        }
    }

    @Test("Fixed-do solfège names", arguments: [
        (40, "Mi2"), (45, "La2"), (50, "Re3"), (55, "Sol3"), (59, "Si3"), (60, "Do4"),
    ])
    func solfege(midi: Int, label: String) {
        #expect(Note(midi: midi).label(notation: .solfege) == label)
    }

    @Test("Accidentals in solfège")
    func solfegeAccidentals() {
        #expect(Note(midi: 54, spelling: .sharps).label(notation: .solfege) == "Fa♯3")
        #expect(Note(midi: 58, spelling: .flats).label(notation: .solfege) == "Si♭3")
    }

    @Test("Nearest note and cents deviation")
    func nearest() throws {
        let exact = try #require(Note.nearest(to: 440))
        #expect(exact.note.midi == 69)
        #expect(abs(exact.cents) < 1e-9)

        // 20 cents sharp of A4.
        let sharp = try #require(Note.nearest(to: 440 * pow(2, 20.0 / 1200)))
        #expect(sharp.note.midi == 69)
        #expect(abs(sharp.cents - 20) < 1e-6)

        #expect(Note.nearest(to: 0) == nil)
        #expect(Note.nearest(to: .nan) == nil)
    }

    @Test("Cents math is symmetric")
    func centsMath() {
        #expect(abs(PitchMath.cents(from: 880, to: 440) - 1200) < 1e-9)
        #expect(abs(PitchMath.cents(from: 220, to: 440) + 1200) < 1e-9)
        #expect(PitchMath.cents(from: 440, to: 440) == 0)
    }
}
