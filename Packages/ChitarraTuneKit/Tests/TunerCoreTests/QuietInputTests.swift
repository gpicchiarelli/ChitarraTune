import Foundation
import Testing
@testable import TunerCore

/// A quiet source in a quiet room: an unplugged electric guitar, or the thin top strings, heard by a
/// computer's built-in microphone. They sit below a fixed −48 dBFS gate even though the room is far
/// quieter still, and the tuner stayed silent until the input gain was raised.
@Suite("Quiet input")
struct QuietInputTests {
    private static let rate = 48_000.0

    /// `lead` seconds of the room alone, then the pluck (the room continuing underneath).
    private func performance(string: Int, amplitude: Double, room: Double, hum: Double? = nil, lead: Double = 0.6) -> [Float] {
        let note = Tuning.standard.strings[string]
        let hum = hum ?? room / 2
        var model = StringModel(roomNoise: room, hum: hum, amplitude: amplitude)
        model.attackNoise = 0.15
        let silence = StringModel(roomNoise: room, hum: hum, amplitude: 0)
            .pluck(frequency: note.frequency(), sampleRate: Self.rate, duration: lead)
        return silence + model.pluck(frequency: note.frequency(), sampleRate: Self.rate, duration: 1.5)
    }

    private func readings(_ signal: [Float]) -> [TunerReading] {
        var engine = TuningEngine()
        return signal.chunked(1_024).compactMap { engine.process($0, sampleRate: Self.rate)?.reading }.filter { !$0.isHeld }
    }

    private func level(_ samples: ArraySlice<Float>) -> Double {
        (samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)).squareRoot()
    }

    @Test("The top strings played softly into a quiet room are heard and measured", arguments: [4, 5])
    func quietTopStrings(string: Int) throws {
        let signal = performance(string: string, amplitude: 0.006, room: 0.00015)
        let pluck = signal.dropFirst(Int(0.6 * Self.rate)).prefix(Int(0.3 * Self.rate))
        #expect(level(pluck) < EngineParameters.standard.gateOpenLevel, "the pluck must be below the fixed gate to test this")
        let found = readings(signal)
        try #require(found.count >= 10, "only \(found.count) readings")
        #expect(found.allSatisfy { $0.stringIndex == string })
        let errors = found.dropFirst(found.count / 3).map { abs($0.cents) }.sorted()
        #expect(errors[errors.count / 2] < 1, "median error \(errors[errors.count / 2]) ¢")
    }

    @Test("A room alone never produces a reading, however quiet or noisy", arguments: [0.000_05, 0.000_3, 0.001, 0.003, 0.01])
    func roomAlone(noise: Double) {
        let room = StringModel(roomNoise: noise, hum: noise / 2, amplitude: 0).pluck(frequency: 110, sampleRate: Self.rate, duration: 4)
        #expect(readings(room).isEmpty)
    }

    @Test("A long, soft note keeps the gate open to the end: the noise floor does not learn from it")
    func sustainedSoftNote() {
        let f = Tuning.standard.strings[5].frequency()
        let room = StringModel(roomNoise: 0.000_15, hum: 0, amplitude: 0).pluck(frequency: f, sampleRate: Self.rate, duration: 0.6)
        let tone = SignalGenerator.tone(frequency: f, sampleRate: Self.rate, duration: 4, harmonics: SignalGenerator.guitarHarmonics, amplitude: 0.003)
        var engine = TuningEngine()
        let frames = (room + tone).chunked(1_024).compactMap { engine.process($0, sampleRate: Self.rate) }
        let last = frames.suffix(Int(0.5 * Self.rate / 1_024))
        #expect(last.allSatisfy { $0.isSignalPresent && $0.reading?.isHeld == false }, "the gate closed on a note that was still sounding")
    }

    /// The first field test: an electric guitar through an amplifier turned down low, into an iMac's
    /// microphone. The wound strings tuned; the B and the top E did not move the needle until the
    /// amplifier was turned up. An amplifier that is merely switched on idles with mains hum, which is
    /// *below* every string of the tuning — and the gate, which judged the level of the whole input,
    /// learned that hum as its noise floor and raised its threshold by the same factor. A string was
    /// masked by interference it does not share a single frequency with. The gate now judges the level
    /// after ``PresenceMeter``, so this pluck — which needed 0.012 before, and 0.003 in silence — is
    /// heard at 0.008.
    ///
    /// At 0.008 the string is only about 12 dB above the hum and the measurement is genuinely noisy:
    /// readings spread over 9 cents and the median lands a few cents out, flat on the low E (−3.5)
    /// and sharp on the G (+3.3), so it is interference and low signal rather than a bias with a
    /// direction. What is asserted there is what the fix is about — the string is *heard* and
    /// identified — with a bound loose enough not to sit on top of that spread but far inside the
    /// 20 cents that would show as badly out of tune. Ten times the level over the same amplifier is
    /// measured as accurately as in silence, which the second half of this test holds.
    @Test("An amplifier idling with mains hum does not mask the strings above it", arguments: [0, 3, 4, 5])
    func amplifierHumDoesNotMask(string: Int) throws {
        func measure(amplitude: Double) throws -> Double {
            let found = readings(performance(string: string, amplitude: amplitude, room: 0.000_3, hum: 0.001))
            try #require(found.count >= 10, "only \(found.count) readings at \(amplitude) with the amplifier idling")
            #expect(found.allSatisfy { $0.stringIndex == string })
            let errors = found.dropFirst(found.count / 3).map { abs($0.cents) }.sorted()
            return errors[errors.count / 2]
        }
        let barelyAbove = try measure(amplitude: 0.008)
        #expect(barelyAbove < 8, "median error \(barelyAbove) ¢ just above the hum")
        let played = try measure(amplitude: 0.03)
        #expect(played < 1.1, "median error \(played) ¢ at a normal pluck over an idling amplifier")
    }

    @Test("In a noisy room the gate keeps its fixed level: a pluck under it stays silent")
    func noisyRoomKeepsTheFixedGate() {
        let signal = performance(string: 5, amplitude: 0.006, room: 0.003)
        let found = readings(signal)
        #expect(found.count < 3, "\(found.count) readings from a pluck buried in a noisy room")
    }

    @Test("Diagnostics say why the needle does not move: below the gate, unclear, or out of range")
    func rejectionReasons() {
        var engine = TuningEngine()
        _ = engine.process(SignalGenerator.silence(count: 48_000), sampleRate: Self.rate)
        #expect(engine.counts.belowGate > 30 && engine.counts.unclear == 0)

        var noise = RandomNoise()
        let loudNoise = (0..<48_000).map { _ in Float(0.05 * noise.next()) }
        let beforeNoise = engine.counts
        _ = engine.process(loudNoise, sampleRate: Self.rate)
        #expect((engine.counts - beforeNoise).unclear > 30)

        // Automatic mode, a clear 470 Hz: inside the search range, 640 cents above the nearest string.
        var automatic = TuningEngine()
        _ = automatic.process(SignalGenerator.tone(frequency: 470, sampleRate: Self.rate, duration: 1, harmonics: [1], amplitude: 0.3),
                              sampleRate: Self.rate)
        #expect(automatic.counts.outOfRange > 30)
        #expect(automatic.counts.analyses == automatic.counts.outOfRange + automatic.counts.belowGate + automatic.counts.unclear)
    }
}

/// A small deterministic noise source (xorshift), uniform in −1…1.
private struct RandomNoise {
    private var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 2_000_001) / 1_000_000 - 1
    }
}
