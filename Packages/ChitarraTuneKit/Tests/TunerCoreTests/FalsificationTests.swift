import Foundation
import Testing
@testable import TunerCore

/// Signals built to break the assumptions the rest of this suite is made of.
///
/// ``StringModel`` gives every partial the frequency `k·f0·√(1 + B·k²)` — which is the very law
/// ``PitchDetector/refine(_:lowPassed:)`` exists to undo. Checking the refinement against it is
/// checking a correction against a signal that assumes the same physics, and a real string is not
/// obliged to agree: its stiffness varies along its length, its two polarisations are detuned from
/// each other and beat, the body resonates back into it, and the partials do not all decay together.
/// A recorded guitar is what would settle this (`RecordingCorpusTests`, blocker B1); until there is
/// one, these are the cases that at least cannot be right by construction.
///
/// Each partial is stated outright — frequency, weight, decay — so a test can make the spectrum
/// anything at all, including things no `B` could produce.
struct AdversarialString {
    struct Partial: Sendable {
        var frequency: Double
        var weight: Double
        /// Decay time to 1/e, in seconds.
        var decay: Double
    }

    var partials: [Partial]
    var amplitude = 0.3
    var noise = 0.002
    var seed: UInt64 = 0x2545F4914F6CDD1D

    func render(sampleRate: Double, duration: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var random = Random(seed: seed)
        let usable = partials.filter { $0.frequency < sampleRate * 0.45 && $0.weight > 0 }
        let norm = usable.reduce(0) { $0 + $1.weight }
        guard norm > 0, count > 0 else { return [Float](repeating: 0, count: max(0, count)) }
        let phases = usable.map { _ in random.unit() * 2 * .pi }

        var output = [Float](repeating: 0, count: count)
        for n in 0..<count {
            let t = Double(n) / sampleRate
            var value = 0.0
            for (index, partial) in usable.enumerated() {
                value += partial.weight * exp(-t / partial.decay)
                    * sin(2 * .pi * partial.frequency * t + phases[index])
            }
            output[n] = Float(amplitude * value / norm + noise * random.symmetric())
        }
        return output
    }

    private struct Random {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func symmetric() -> Double { unit() * 2 - 1 }
    }
}

@Suite("Falsification: strings the model cannot describe")
struct FalsificationTests {
    private let rate = 44_100.0

    /// Partial `k` of a string with stiffness `b`: the law ``StringModel`` uses, so a case can start
    /// from it and then break it. Written out step by step — the type checker gives up on it inline.
    private static func stiff(_ k: Int, f0: Double, b: Double = 1.2e-4) -> Double {
        let index = Double(k)
        let stretch: Double = (1 + b * index * index).squareRoot()
        return index * f0 * stretch
    }

    /// Plays `signal` and returns the settled readings (the first 300 ms of attack dropped).
    private func settled(_ signal: [Float], tuning: Tuning = .standard) throws -> [TunerReading] {
        var engine = TuningEngine(configuration: .init(tuning: tuning))
        var readings: [TunerReading] = []
        for chunk in signal.chunked(1_024) {
            if let reading = engine.process(chunk, sampleRate: rate)?.reading, !reading.isHeld {
                readings.append(reading)
            }
        }
        let skip = Int(0.3 / EngineParameters.standard.hopDuration)
        let rest = Array(readings.dropFirst(skip))
        try #require(rest.count >= 10, "only \(rest.count) settled readings")
        return rest
    }

    /// Median deviation from `truth`, in cents, over the settled readings, and the string chosen.
    private func error(_ readings: [TunerReading], from truth: Double) -> (cents: Double, string: Int) {
        let errors = readings.map { abs(PitchMath.cents(from: $0.frequency, to: truth)) }.sorted()
        return (errors[errors.count / 2], readings[readings.count / 2].stringIndex)
    }

    /// The whole point: partial `k` is not where `√(1 + B·k²)` puts it. Each one is nudged by up to
    /// ±8 cents on top of a plausible stiffness, which is an amount no single `B` can produce for all
    /// of them at once. The refinement measures the fundamental in a band the upper partials have been
    /// taken out of, so their arrangement should not reach the reading at all.
    @Test("A string whose partials obey no stiffness law at all", arguments: [82.41, 110.0, 146.83, 196.0])
    func partialsOffTheLaw(f0: Double) throws {
        var random = SystemNudges(seed: 0xA5A5_F00D_1234_5678)
        let partials = (1...12).map { k -> AdversarialString.Partial in
            let base = Self.stiff(k, f0: f0)
            let nudge: Double = k == 1 ? 0 : random.symmetric() * 8    // cents, and not a law
            let decay: Double = 2.5 / (1 + 0.08 * pow(Double(k), 1.5))
            return .init(frequency: base * pow(2, nudge / 1_200), weight: 1 / Double(k), decay: decay)
        }
        let readings = try settled(AdversarialString(partials: partials).render(sampleRate: rate, duration: 2))
        let measured = error(readings, from: f0)
        print("FALSIFY partials-off-law \(f0) Hz: \(measured.cents) cents, string \(measured.string)")
        #expect(measured.cents <= Self.envelope, "\(measured.cents) cents on a string with no stiffness law")
    }

    /// Bridge coupling: the fundamental dies in 0.6 s while the second partial rings for three, so
    /// halfway through the note the spectrum inverts and what the detector is looking at is mostly an
    /// octave up. The octave logic and the refinement have to hold the string through that.
    @Test("A string whose fundamental dies before its second partial")
    func invertedDecay() throws {
        let f0 = 110.0
        let partials: [AdversarialString.Partial] = [
            .init(frequency: f0, weight: 1.0, decay: 0.6),
            .init(frequency: 2 * f0 * 1.0002, weight: 0.9, decay: 3.0),
            .init(frequency: 3 * f0 * 1.0005, weight: 0.4, decay: 2.0),
            .init(frequency: 4 * f0 * 1.0010, weight: 0.2, decay: 1.5),
        ]
        let readings = try settled(AdversarialString(partials: partials).render(sampleRate: rate, duration: 2.5))
        let measured = error(readings, from: f0)
        print("FALSIFY inverted-decay: \(measured.cents) cents, string \(measured.string)")
        #expect(measured.string == 1, "the A string, not its octave")
        #expect(measured.cents <= Self.envelope)
    }

    /// The two polarisations of a real string are not the same length and beat against each other.
    /// There is no single true pitch here, so the claim is the honest one: the reading sits inside the
    /// pair, near its midpoint, instead of latching to one of them or wandering between.
    @Test("A string beating against its own second polarisation")
    func polarisationBeat() throws {
        let f0 = 110.0
        let split = pow(2, 4.0 / 1_200)                                // 4 cents apart, ~0.25 Hz
        var partials: [AdversarialString.Partial] = []
        for k in 1...8 {
            let base = Self.stiff(k, f0: f0)
            partials.append(.init(frequency: base, weight: 1 / Double(k), decay: 2.5))
            partials.append(.init(frequency: base * split, weight: 0.85 / Double(k), decay: 2.2))
        }
        let midpoint = f0 * pow(2, 2.0 / 1_200)
        let readings = try settled(AdversarialString(partials: partials).render(sampleRate: rate, duration: 2.5))
        let measured = error(readings, from: midpoint)
        print("FALSIFY polarisation-beat: \(measured.cents) cents from the midpoint, string \(measured.string)")
        #expect(measured.cents <= Self.envelope)
    }

    /// The guitar's main air resonance sits near the low strings and rings back into the signal at a
    /// frequency that is not a partial of anything — a second tone inside the band the refinement
    /// measures in, which no filter can remove without taking the fundamental with it.
    ///
    /// This is the case that found a limit rather than confirming a promise, so it is written as a
    /// characterisation and not as a pass. Measured at A2 with the resonance at 96, 102 and 106 Hz
    /// and at a fifth to four fifths of the fundamental's amplitude:
    ///
    /// | interferer | 0.2 | 0.4 | 0.6 | 0.8 |
    /// | --- | ---: | ---: | ---: | ---: |
    /// | 96 Hz | 1.6 | 3.4 | 3.4 | 4.7 |
    /// | 102 Hz | 1.2 | 1.8 | 6.0 | 5.9 |
    /// | 106 Hz | 0.9 | 1.8 | 2.4 | 2.8 |
    ///
    /// Up to two fifths the reading stays inside the in-tune window. Past it the error reaches six
    /// cents — at which point the "resonance" is a second note as loud as the string, and every period
    /// estimator lands between two tones it cannot separate. The string chosen is right throughout.
    /// `docs/ACCURACY.md` states the bound; here it is checked, so it cannot quietly get worse.
    @Test("A body resonance a few hertz from the fundamental")
    func bodyResonance() throws {
        let f0 = 110.0
        let partials = (1...10).map { k in
            AdversarialString.Partial(frequency: Self.stiff(k, f0: f0), weight: 1 / Double(k), decay: 2.5)
        }
        for frequency in [96.0, 102.0, 106.0] {
            for weight in [0.2, 0.4, 0.6, 0.8] {
                var probe = partials
                probe.append(.init(frequency: frequency, weight: weight, decay: 0.9))
                let readings = try settled(AdversarialString(partials: probe).render(sampleRate: rate, duration: 2))
                let measured = error(readings, from: f0)
                print("FALSIFY body \(frequency) Hz weight \(weight): \(measured.cents) cents, string \(measured.string)")
                #expect(measured.string == 1, "\(frequency) Hz at \(weight): the A string, not the interferer")
                let bound = weight <= 0.4 ? Self.envelope : Self.interferedEnvelope
                #expect(measured.cents <= bound, "\(frequency) Hz at \(weight): \(measured.cents) cents, bound \(bound)")
            }
        }
    }

    /// A small microphone can lose the fundamental of a low string completely, not merely attenuate
    /// it. What is left is partials 2 upwards, whose spacing is the fundamental and whose stiffness
    /// bias is the largest: the case the refinement was written for, with nothing left to refine
    /// against.
    @Test("A low string with no fundamental left in the signal")
    func missingFundamental() throws {
        let f0 = 82.41
        let partials = (2...12).map { k in
            AdversarialString.Partial(frequency: Self.stiff(k, f0: f0, b: 1.5e-4), weight: 1 / Double(k), decay: 2.2)
        }
        let readings = try settled(AdversarialString(partials: partials).render(sampleRate: rate, duration: 2))
        let measured = error(readings, from: f0)
        print("FALSIFY missing-fundamental: \(measured.cents) cents, string \(measured.string)")
        #expect(measured.string == 0, "the low E, not one of its partials")
        #expect(measured.cents <= Self.envelope)
    }

    /// The bound these cases are held to. It is not the 0.16 cent of `docs/ACCURACY.md`: that number
    /// belongs to signals built the way the engine expects, and quoting it here would be the same
    /// circularity in a new place. This is the width of the in-tune window, which is the claim that
    /// actually matters to somebody tuning a guitar — the tuner tells the truth about whether the
    /// string is in tune, even when the string is nothing like the model.
    static let envelope = EngineParameters.standard.inTuneThreshold

    /// The bound when a tone that is not the string's, and more than two fifths as loud as its
    /// fundamental, sits inside the band the refinement measures in. Measured at six cents (see
    /// ``bodyResonance()``); this leaves a cent of room and no more, so a regression still fails.
    static let interferedEnvelope = 7.0

    /// A fixed nudge sequence, so a failure is reproducible to the cent.
    private struct SystemNudges {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func symmetric() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state >> 11) / Double(1 << 53) * 2 - 1
        }
    }
}
