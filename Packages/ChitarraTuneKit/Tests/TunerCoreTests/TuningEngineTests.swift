import Foundation
import Testing
@testable import TunerCore

@Suite("TuningEngine")
struct TuningEngineTests {
    private let sampleRate = 44_100.0

    /// Streams `signal` in capture-sized chunks and returns every produced frame.
    private func run(_ engine: inout TuningEngine, _ signal: [Float], chunk: Int = 1_024) -> [TunerFrame] {
        signal.chunked(chunk).compactMap { engine.process($0, sampleRate: sampleRate) }
    }

    private func pluck(_ midi: Int, cents: Double = 0, duration: Double = 0.6, amplitude: Double = 0.3) -> [Float] {
        let frequency = Note(midi: midi).frequency() * pow(2, cents / 1200)
        return SignalGenerator.tone(
            frequency: frequency,
            sampleRate: sampleRate,
            duration: duration,
            harmonics: SignalGenerator.guitarHarmonics,
            amplitude: amplitude
        )
    }

    // MARK: Auto mode

    @Test("Automatic mode identifies every string of every tuning",
          arguments: Tuning.catalog)
    func identifiesStrings(tuning: Tuning) throws {
        for (index, note) in tuning.strings.enumerated() {
            var engine = TuningEngine(configuration: .init(tuning: tuning))
            let frames = run(&engine, pluck(note.midi, cents: 8))
            let reading = try #require(frames.last?.reading, "\(tuning.id) \(note.label())")
            #expect(reading.stringIndex == index, "\(tuning.id) \(note.label())")
            #expect(abs(reading.cents - 8) < 1, "\(tuning.id) \(note.label()) → \(reading.cents)")
        }
    }

    @Test("Deviation sign: flat is negative, sharp is positive")
    func sign() throws {
        var flat = TuningEngine()
        var sharp = TuningEngine()
        let flatReading = try #require(run(&flat, pluck(45, cents: -25)).last?.reading)
        let sharpReading = try #require(run(&sharp, pluck(45, cents: 25)).last?.reading)
        #expect(flatReading.cents < -20)
        #expect(sharpReading.cents > 20)
    }

    @Test("A4 calibration shifts the targets")
    func calibration() throws {
        // An A string tuned to an A4 = 446 Hz orchestra is 23 cents sharp of 440 but exactly in tune at 446.
        let tone = SignalGenerator.tone(frequency: 110 * 446 / 440, sampleRate: sampleRate,
                                        harmonics: SignalGenerator.guitarHarmonics)
        var at440 = TuningEngine(configuration: .init(referenceA: 440))
        var at446 = TuningEngine(configuration: .init(referenceA: 446))
        let off = try #require(run(&at440, tone).last?.reading)
        let on = try #require(run(&at446, tone).last?.reading)
        #expect(abs(off.cents) > 10)
        #expect(abs(on.cents) < 1)
    }

    // MARK: Stability

    @Test("Becomes in tune only after a stable run, and exits with hysteresis")
    func stability() throws {
        var engine = TuningEngine()
        // The first frames arrive once the window is full; six in-tune hops are needed on top.
        let early = run(&engine, pluck(40, cents: 1, duration: 0.1))
        #expect(early.compactMap(\.reading).allSatisfy { !$0.isInTune })

        let settled = run(&engine, pluck(40, cents: 1, duration: 0.6))
        #expect(try #require(settled.last?.reading).isInTune)

        // A large error must clear the flag.
        let off = run(&engine, pluck(40, cents: 30, duration: 0.6))
        #expect(try #require(off.last?.reading).isInTune == false)
    }

    @Test("Off-pitch strings never report in tune")
    func neverInTuneWhenOff() {
        var engine = TuningEngine()
        let frames = run(&engine, pluck(50, cents: 20, duration: 1))
        #expect(frames.compactMap(\.reading).allSatisfy { !$0.isInTune })
    }

    // MARK: Gate & hold

    @Test("Quiet input is gated out")
    func noiseGate() {
        var engine = TuningEngine()
        let frames = run(&engine, pluck(45, amplitude: 0.0008))
        #expect(!frames.isEmpty)
        #expect(frames.allSatisfy { $0.reading == nil && !$0.isSignalPresent })
    }

    @Test("Silence and noise produce no reading")
    func silenceAndNoise() {
        var engine = TuningEngine()
        let silence = run(&engine, SignalGenerator.silence(count: 20_000))
        #expect(silence.allSatisfy { $0.reading == nil })

        let noise = run(&engine, SignalGenerator.noise(count: 30_000, amplitude: 0.05))
        #expect(noise.allSatisfy { $0.reading == nil })
    }

    @Test("Last reading is held briefly after the note fades, then cleared")
    func hold() throws {
        var engine = TuningEngine()
        _ = run(&engine, pluck(45, duration: 0.5))

        let shortSilence = run(&engine, SignalGenerator.silence(count: Int(0.3 * sampleRate)))
        let held = try #require(shortSilence.last?.reading)
        #expect(held.isHeld)
        #expect(held.stringIndex == 1)

        let longSilence = run(&engine, SignalGenerator.silence(count: Int(1.2 * sampleRate)))
        #expect(longSilence.last?.reading == nil)
    }

    // MARK: Manual mode

    @Test("Manual mode measures against the pinned string")
    func manualTarget() throws {
        var engine = TuningEngine(configuration: .init(target: .string(0))) // E2
        let reading = try #require(run(&engine, pluck(40, cents: -15)).last?.reading)
        #expect(reading.stringIndex == 0)
        #expect(abs(reading.cents + 15) < 1)
    }

    @Test("Manual mode ignores other strings instead of mislabelling them")
    func manualIgnoresOtherStrings() {
        var engine = TuningEngine(configuration: .init(target: .string(0))) // E2
        // A2 is 500 cents away from E2 → beyond the accepted deviation.
        let frames = run(&engine, pluck(45))
        #expect(frames.compactMap(\.reading).isEmpty)
    }

    @Test("Manual mode narrows the search so upper partials cannot win",
          arguments: [(0, 40), (2, 50), (5, 64)])
    func manualStrongOvertone(index: Int, midi: Int) throws {
        // Weak fundamental, dominant 2nd harmonic: the classic octave-up failure.
        let frequency = Note(midi: midi).frequency() * pow(2, 4.0 / 1200)
        let tone = SignalGenerator.tone(frequency: frequency, sampleRate: sampleRate, duration: 0.6,
                                        harmonics: SignalGenerator.weakFundamental)
        var engine = TuningEngine(configuration: .init(target: .string(index)))
        let reading = try #require(run(&engine, tone).last?.reading)
        #expect(reading.stringIndex == index)
        #expect(abs(reading.cents - 4) < 1.5, "\(reading.cents)")
    }

    @Test("An out-of-range manual index is clamped")
    func manualClamp() throws {
        var engine = TuningEngine(configuration: .init(target: .string(99)))
        let reading = try #require(run(&engine, pluck(64)).last?.reading)
        #expect(reading.stringIndex == 5)
    }

    // MARK: Reconfiguration

    @Test("Changing configuration discards the previous reading")
    func reconfigureResets() throws {
        var engine = TuningEngine()
        _ = run(&engine, pluck(40, duration: 0.6))
        engine.reconfigure(.init(tuning: .tuning(for: .dropD)))
        let frames = run(&engine, pluck(38, duration: 0.6))
        let reading = try #require(frames.last?.reading)
        #expect(reading.stringIndex == 0)
        #expect(reading.note.label() == "D2")
    }

    @Test("A4 is clamped to the supported range")
    func clampReference() {
        #expect(TunerConfiguration(referenceA: 1_000).referenceA == 466)
        #expect(TunerConfiguration(referenceA: 10).referenceA == 415)
    }

    @Test("Sample-rate changes rebuild the detector")
    func sampleRateChange() throws {
        var engine = TuningEngine()
        _ = run(&engine, pluck(45))
        let fresh = SignalGenerator.tone(frequency: 110, sampleRate: 48_000, duration: 0.6,
                                         harmonics: SignalGenerator.guitarHarmonics)
        let frame = fresh.chunked(1_024).compactMap { engine.process($0, sampleRate: 48_000) }.last
        let reading = try #require(frame?.reading)
        #expect(abs(reading.cents) < 1)
    }

    @Test("Degenerate input is ignored")
    func degenerateInput() {
        var engine = TuningEngine()
        #expect(engine.process([], sampleRate: 44_100) == nil)
        #expect(engine.process([0.1, 0.2], sampleRate: 0) == nil)
        #expect(engine.process([0.1, 0.2], sampleRate: 44_100) == nil) // not enough audio yet
    }
}
