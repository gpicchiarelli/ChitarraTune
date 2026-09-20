import Foundation
import Testing
@testable import TunerCore

@Suite("PitchDetector")
struct PitchDetectorTests {
    private func detector(_ sampleRate: Double = 44_100, tuning: Tuning = .standard) throws -> PitchDetector {
        try #require(PitchDetector(sampleRate: sampleRate, frequencyRange: tuning.detectionRange()))
    }

    @Test("Rejects invalid parameters")
    func invalidParameters() {
        #expect(PitchDetector(sampleRate: 0, frequencyRange: 70...600) == nil)
        #expect(PitchDetector(sampleRate: 44_100, frequencyRange: 0...600) == nil)
        #expect(PitchDetector(sampleRate: 1_000, frequencyRange: 70...600) == nil)
        #expect(PitchDetector(sampleRate: 44_100, frequencyRange: 100...100.05) == nil) // fewer than 3 usable lags
    }

    @Test("Needs a full analysis window")
    func tooFewSamples() throws {
        let detector = try detector()
        let short = SignalGenerator.tone(frequency: 110, duration: 0.02)
        #expect(short.count < detector.requiredSampleCount)
        #expect(detector.estimate(in: short) == nil)
    }

    @Test("Silence and DC offset carry no pitch")
    func silence() throws {
        let detector = try detector()
        let n = detector.requiredSampleCount
        #expect(detector.estimate(in: SignalGenerator.silence(count: n)) == nil)
        #expect(detector.estimate(in: [Float](repeating: 0.4, count: n)) == nil)
    }

    @Test("A DC offset does not change the measured pitch")
    func dcOffset() throws {
        let detector = try detector()
        let tone = SignalGenerator.tone(frequency: 110, amplitude: 0.2).map { $0 + 0.35 }
        let estimate = try #require(detector.estimate(in: tone))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: 110)) < 0.5)
    }

    @Test("Pure sines within 0.5 cent, both common sample rates",
          arguments: [44_100.0, 48_000.0],
          [82.4069, 110.0, 146.8324, 195.9977, 246.9417, 329.6276])
    func sines(sampleRate: Double, frequency: Double) throws {
        let detector = try detector(sampleRate)
        let signal = SignalGenerator.tone(frequency: frequency, sampleRate: sampleRate)
        let estimate = try #require(detector.estimate(in: signal))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: frequency)) < 0.5)
        #expect(estimate.clarity > 0.9)
    }

    @Test("Guitar-like harmonic tones keep the right octave",
          arguments: Tuning.standard.strings.map { $0.frequency() })
    func harmonicTones(frequency: Double) throws {
        let detector = try detector()
        let signal = SignalGenerator.tone(frequency: frequency, harmonics: SignalGenerator.guitarHarmonics)
        let estimate = try #require(detector.estimate(in: signal))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: frequency)) < 1)
    }

    @Test("Weak-fundamental low strings are not reported an octave up",
          arguments: [82.4069, 110.0, 146.8324])
    func weakFundamental(frequency: Double) throws {
        let detector = try detector()
        let signal = SignalGenerator.tone(frequency: frequency, harmonics: SignalGenerator.weakFundamental)
        let estimate = try #require(detector.estimate(in: signal))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: frequency)) < 1.5,
                "got \(estimate.frequency) Hz for \(frequency) Hz")
    }

    @Test("Detuned strings are measured, not snapped", arguments: [-40.0, -12.0, -3.0, 3.0, 12.0, 40.0])
    func detuned(cents: Double) throws {
        let target = 110.0
        let played = target * pow(2, cents / 1200)
        let detector = try detector()
        let estimate = try #require(detector.estimate(in: SignalGenerator.tone(frequency: played)))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: played)) < 0.5)
    }

    @Test("Drop C's 65.4 Hz string is inside the detection range")
    func dropC() throws {
        let tuning = Tuning.tuning(for: .dropC)
        let detector = try detector(tuning: tuning)
        let low = tuning.strings[0].frequency()
        let signal = SignalGenerator.tone(frequency: low, harmonics: SignalGenerator.guitarHarmonics)
        let estimate = try #require(detector.estimate(in: signal))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: low)) < 1)
    }

    @Test("Uses only the newest samples")
    func usesSuffix() throws {
        let detector = try detector()
        let old = SignalGenerator.tone(frequency: 330, duration: 0.3)
        let fresh = SignalGenerator.tone(frequency: 110, duration: 0.5)
        let estimate = try #require(detector.estimate(in: old + fresh))
        #expect(abs(PitchMath.cents(from: estimate.frequency, to: 110)) < 0.5)
    }

    @Test("Broadband noise has low clarity")
    func noise() throws {
        let detector = try detector()
        let noise = SignalGenerator.noise(count: detector.requiredSampleCount, amplitude: 0.3)
        if let estimate = detector.estimate(in: noise) {
            #expect(estimate.clarity < 0.5)
        }
    }
}

@Suite("PitchDetector — properties & performance")
struct PitchDetectorPropertyTests {
    /// Deterministic pseudo-random frequencies across the guitar range: the estimate must stay within
    /// one cent whatever the pitch, harmonic content or sample rate.
    @Test("Accuracy holds across the whole guitar range", arguments: [44_100.0, 48_000.0])
    func sweep(sampleRate: Double) throws {
        let detector = try #require(PitchDetector(sampleRate: sampleRate, frequencyRange: Tuning.standard.detectionRange()))
        var generator = SystemRandomNumberGeneratorSeeded(seed: 42)
        for _ in 0..<60 {
            let frequency = 82 * pow(2, Double.random(in: 0...2.1, using: &generator)) // E2 … ~E4
            let harmonics = Bool.random(using: &generator) ? SignalGenerator.guitarHarmonics : [1, 0.3, 0.1]
            let signal = SignalGenerator.tone(frequency: frequency, sampleRate: sampleRate, harmonics: harmonics)
            let estimate = try #require(detector.estimate(in: signal), "\(frequency) Hz")
            #expect(abs(PitchMath.cents(from: estimate.frequency, to: frequency)) < 1, "\(frequency) Hz → \(estimate.frequency)")
        }
    }

    @Test("One analysis stays far below the hop time (regression guard for accidental O(n²))")
    func speed() throws {
        let detector = try #require(PitchDetector(sampleRate: 48_000, frequencyRange: Tuning.standard.detectionRange()))
        let signal = SignalGenerator.tone(frequency: 110, sampleRate: 48_000, harmonics: SignalGenerator.guitarHarmonics)
        let clock = ContinuousClock()
        let runs = 50
        let elapsed = clock.measure { for _ in 0..<runs { _ = detector.estimate(in: signal) } }
        let perAnalysis = elapsed / runs
        // Release measures ≈23 µs on an Apple M4 (≈0.1 % of a 25 ms hop); unoptimised debug builds are
        // ~50× slower. Either way it must stay well inside one hop.
        #if DEBUG
        let budget = Duration.milliseconds(20)
        #else
        let budget = Duration.milliseconds(2)
        #endif
        #expect(perAnalysis < budget, "took \(perAnalysis) per analysis")
    }

    @Test("Repeated analyses give identical results (no state leaks between calls)")
    func deterministic() throws {
        let detector = try #require(PitchDetector(sampleRate: 44_100, frequencyRange: Tuning.standard.detectionRange()))
        let a = SignalGenerator.tone(frequency: 196, harmonics: SignalGenerator.guitarHarmonics)
        let b = SignalGenerator.tone(frequency: 330, harmonics: SignalGenerator.guitarHarmonics)
        let first = detector.estimate(in: a)
        _ = detector.estimate(in: b)
        #expect(detector.estimate(in: a) == first)
    }
}

/// `SystemRandomNumberGenerator` is not seedable; this xorshift keeps the sweep reproducible.
struct SystemRandomNumberGeneratorSeeded: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
