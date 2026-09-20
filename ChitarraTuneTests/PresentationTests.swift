import Foundation
import Testing
import TunerAudio
import TunerCore
@testable import ChitarraTune

/// What the app turns model values into: note parts, spoken names, signed numbers, tuning titles and
/// failure text. It lives in the app target because it reads the app's string catalog, so `swift test`
/// cannot reach it; these tests run inside the app (ADR 0005).
@Suite("Presentation")
struct PresentationTests {
    private func parts(_ note: Note, _ notation: NoteNotation) -> [String] {
        let parts = NoteParts(note, notation: notation)
        return [parts.letter, parts.accidental, parts.octave]
    }

    @Test("A note splits into letter, accidental and octave, in both notations")
    func noteParts() {
        #expect(parts(Note(midi: 40), .english) == ["E", "", "2"])
        #expect(parts(Note(midi: 40), .solfege) == ["Mi", "", "2"])
        #expect(parts(Note(midi: 39, spelling: .flats), .english) == ["E", "♭", "2"])
        #expect(parts(Note(midi: 42, spelling: .sharps), .solfege) == ["Fa", "♯", "2"])
    }

    /// VoiceOver must say "E flat", never the symbol ♭, which every speech engine guesses differently.
    @Test("VoiceOver gets words, not symbols, for every accidental")
    func spokenNames() {
        let names = [Note(midi: 40), Note(midi: 39, spelling: .flats), Note(midi: 42, spelling: .sharps)]
            .map { $0.spokenName(.english) }
        for name in names {
            #expect(!name.contains("♭") && !name.contains("♯"), "\(name) still has a symbol")
            #expect(name.contains("2"), "\(name) does not say the octave")
        }
        #expect(Set(names).count == 3, "flat, natural and sharp must read differently")
        #expect(Note(midi: 40).spokenName(.solfege).hasPrefix("Mi"))
    }

    @Test("Signed numbers use a real minus sign, and zero has no sign")
    func signedText() {
        #expect(3.signedText == "+3")
        #expect(0.signedText == "0")
        #expect((-12).signedText == "\u{2212}12")
        #expect(!(-12).signedText.contains("-"), "U+002D reads badly next to digits")
    }

    @Test("Every tuning has its own title and a summary of its strings")
    func tunings() {
        let titles = TuningID.allCases.map { String(localized: $0.title) }
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == TuningID.allCases.count, "two tunings share a title")
        let standard = Tuning.catalog[0]
        #expect(standard.stringSummary(.english) == "E A D G B E")
        #expect(standard.stringSummary(.solfege) == "Mi La Re Sol Si Mi")
    }

    /// Every failure the capture layer can report must reach the user as text they can act on.
    @Test("Every capture failure has a title, a message and a symbol")
    func failures() {
        let failures: [CaptureFailure] = [
            .microphoneDenied, .microphoneRestricted, .noInputAvailable,
            .inputUnavailable, .engineFailed(code: -10_875), .interrupted, .configurationChanged,
        ]
        for failure in failures {
            #expect(!String(localized: failure.title).isEmpty, "\(failure) has no title")
            #expect(!String(localized: failure.message).isEmpty, "\(failure) has no message")
            #expect(!failure.symbol.isEmpty, "\(failure) has no symbol")
        }
        // Only a denied permission is fixed in system settings; the rest are fixed in the app.
        #expect(failures.filter(\.needsSystemSettings) == [.microphoneDenied])
    }

    @Test("Siri and Shortcuts offer exactly the tunings the catalog has")
    func tuningOptions() {
        let offered = TuningOption.caseDisplayRepresentations.keys
        #expect(Set(offered.map(\.tuningID)) == Set(TuningID.allCases), "Siri offers other tunings than the catalog")
        for option in offered {
            // The raw values are the same strings, so a shortcut saved by one name keeps working.
            #expect(TuningOption(rawValue: option.tuningID.rawValue) == option, "\(option) and its tuning disagree")
        }
    }
}
