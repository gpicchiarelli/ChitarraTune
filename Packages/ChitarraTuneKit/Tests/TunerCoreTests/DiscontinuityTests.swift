import Foundation
import Testing
@testable import TunerCore

@Suite("Stream discontinuities")
struct DiscontinuityTests {
    private let rate = 44_100.0

    private func tone(midi: Int, samples: Int, from offset: Int = 0) -> [Float] {
        let frequency = Note(midi: midi).frequency()
        return (offset..<offset + samples).map { Float(0.3 * sin(2 * Double.pi * frequency * Double($0) / 44_100)) }
    }

    /// Feeds `signal` in 1 024-sample chunks stamped from `start`; returns the frames.
    private func feed(_ engine: inout TuningEngine, _ signal: [Float], stampedFrom start: Int64) -> [TunerFrame] {
        stride(from: 0, to: signal.count, by: 1_024).compactMap { index in
            engine.process(Array(signal[index..<min(index + 1_024, signal.count)]), sampleRate: rate, sampleTime: start + Int64(index))
        }
    }

    @Test("Contiguous timestamps behave exactly like untimed audio")
    func contiguous() {
        var timed = TuningEngine(), untimed = TuningEngine()
        let signal = tone(midi: 45, samples: 30_000)
        let a = feed(&timed, signal, stampedFrom: 1_000)
        let b = stride(from: 0, to: signal.count, by: 1_024).compactMap {
            untimed.process(Array(signal[$0..<min($0 + 1_024, signal.count)]), sampleRate: rate)
        }
        #expect(a == b)
    }

    @Test("A gap discards the history: no frame until a full new window has arrived")
    func gapResetsWindow() {
        var engine = TuningEngine()
        _ = feed(&engine, tone(midi: 45, samples: 30_000), stampedFrom: 0)
        // Resume 10 000 samples later than expected: the old window must not be spliced to the new audio.
        let after = feed(&engine, tone(midi: 45, samples: 1_024, from: 40_000), stampedFrom: 40_000)
        #expect(after.isEmpty, "one chunk is not a full analysis window")
    }

    @Test("A spliced window never produces a reading that was not played")
    func noPhantomPitch() {
        var engine = TuningEngine()
        _ = feed(&engine, tone(midi: 40, samples: 40_000), stampedFrom: 0)     // low E
        let frames = feed(&engine, tone(midi: 64, samples: 40_000, from: 90_000), stampedFrom: 90_000) // high E after a gap
        let fresh = frames.compactMap(\.reading).filter { !$0.isHeld }
        #expect(!fresh.isEmpty)
        #expect(fresh.allSatisfy { $0.note.midi == 64 }, "readings after the gap must come from the new note only")
    }

    /// Regression: the octave-continuity heuristic folded any 2–4× detection back onto the followed
    /// string when the level did not rise, so a higher string played right after a lower one an exact
    /// octave or two apart kept showing the lower one for as long as it sounded.
    @Test("Moving to a string one or two octaves higher is reported, not folded back", arguments: [
        (TuningID.standard, 0, 5),  // E2 → E4
        (TuningID.dropD, 0, 2),     // D2 → D3
        (TuningID.dadgad, 0, 5),    // D2 → D4
        (TuningID.dadgad, 2, 5),    // D3 → D4
        (TuningID.openD, 0, 2),     // D2 → D3
    ])
    func octaveApartStrings(tuning id: TuningID, from low: Int, to high: Int) {
        let tuning = Tuning.tuning(for: id)
        var engine = TuningEngine(configuration: TunerConfiguration(tuning: tuning))
        func play(_ string: Int, _ count: Int, from offset: Int) -> [Float] {
            let f = tuning.strings[string].frequency()
            return (offset..<offset + count).map { n in
                let t = Double(n) / rate
                return Float(0.3 * (0.6 * sin(2 * .pi * f * t) + 0.3 * sin(4 * .pi * f * t) + 0.1 * sin(6 * .pi * f * t)))
            }
        }
        _ = feed(&engine, play(low, 40_000, from: 0), stampedFrom: 0)
        let readings = feed(&engine, play(high, 40_000, from: 40_000), stampedFrom: 40_000).compactMap(\.reading)
        #expect(readings.last?.stringIndex == high, "\(id): still showing string \(readings.last?.stringIndex ?? -1)")
    }

    /// Regression, the other direction: a detection an octave (or two) *below* the followed note was
    /// always folded up onto it, without checking that the lower note was absent. A lower string
    /// plucked softly after a higher one (no level rise, so no attack is detected) kept showing the
    /// higher string for as long as it sounded.
    @Test("Moving softly to a string one or two octaves lower is reported, not folded up", arguments: [
        (TuningID.dropD, 2, 0),     // D3 → D2
        (TuningID.standard, 5, 0),  // E4 → E2
        (TuningID.dadgad, 5, 2),    // D4 → D3
    ])
    func softLowerString(tuning id: TuningID, from high: Int, to low: Int) {
        let tuning = Tuning.tuning(for: id)
        var engine = TuningEngine(configuration: TunerConfiguration(tuning: tuning))
        func play(_ string: Int, _ count: Int, from offset: Int, amplitude: Double) -> [Float] {
            let f = tuning.strings[string].frequency()
            return (offset..<offset + count).map { n in
                let t = Double(n) / rate
                return Float(amplitude * (0.6 * sin(2 * .pi * f * t) + 0.3 * sin(4 * .pi * f * t) + 0.1 * sin(6 * .pi * f * t)))
            }
        }
        _ = feed(&engine, play(high, 40_000, from: 0, amplitude: 0.3), stampedFrom: 0)
        let readings = feed(&engine, play(low, 40_000, from: 40_000, amplitude: 0.2), stampedFrom: 40_000).compactMap(\.reading)
        #expect(readings.last?.stringIndex == low, "\(id): showing string \(readings.last?.stringIndex ?? -1)")
    }

    @Test("A decaying note read an octave low by the detector is still folded back onto it")
    func octaveLowErrorStillFolded() {
        // A string whose second partial dominates as it fades: the detector may take twice the
        // period, but nothing sounds at half the frequency, so the reading stays on the string.
        let f = Tuning.standard.strings[1].frequency()
        var engine = TuningEngine()
        let signal = (0..<60_000).map { n -> Float in
            let t = Double(n) / rate
            let decay = exp(-t / 0.4)
            return Float(0.3 * decay * (0.25 * sin(2 * .pi * f * t) + sin(4 * .pi * f * t) + 0.4 * sin(6 * .pi * f * t)))
        }
        let readings = feed(&engine, signal, stampedFrom: 0).compactMap(\.reading).filter { !$0.isHeld }
        #expect(!readings.isEmpty)
        #expect(readings.allSatisfy { $0.stringIndex == 1 }, "\(readings.map(\.stringIndex))")
    }
}
