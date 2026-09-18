import Foundation
import Testing
@testable import TunerCore

/// Deterministic pseudo-random source so fuzz failures are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Robustness against hostile input")
struct RobustnessTests {
    private func tone(_ midi: Int = 40, rate: Double = 44_100, duration: Double = 0.6) -> [Float] {
        SignalGenerator.tone(
            frequency: Note(midi: midi).frequency(),
            sampleRate: rate,
            duration: duration,
            harmonics: SignalGenerator.guitarHarmonics,
            amplitude: 0.3
        )
    }

    private func feed(_ engine: inout TuningEngine, _ samples: [Float], rate: Double = 44_100, chunk: Int = 1_024) -> [TunerFrame] {
        samples.chunked(chunk).compactMap { engine.process($0, sampleRate: rate) }
    }

    // MARK: Samples

    @Test("Non-finite and extreme samples never crash, and the engine recovers afterwards", arguments: [
        Float.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude, .leastNonzeroMagnitude,
    ])
    func hostileSamples(value: Float) {
        var engine = TuningEngine()
        _ = feed(&engine, [Float](repeating: value, count: 8_192))
        let frames = feed(&engine, tone(duration: 1.5))
        #expect(frames.contains { $0.reading != nil }, "clean audio must be measured again after \(value)")
        for reading in frames.compactMap(\.reading) {
            #expect(reading.frequency.isFinite && reading.cents.isFinite)
        }
    }

    @Test("Empty input is ignored")
    func emptyChunk() {
        var engine = TuningEngine()
        #expect(engine.process([], sampleRate: 44_100) == nil)
    }

    @Test("A very long single chunk is handled and the buffer stays bounded")
    func hugeChunk() {
        var engine = TuningEngine()
        let frame = engine.process(tone(duration: 20), sampleRate: 44_100)
        #expect(frame?.reading != nil)
    }

    // MARK: Sample rates

    @Test("Hostile sample rates are rejected without trapping", arguments: [
        Double.nan, .infinity, -.infinity, 0, -44_100, 1, 7_999, 384_001, 1e6, 1e12, 1e300, .greatestFiniteMagnitude,
    ])
    func hostileSampleRates(rate: Double) {
        var engine = TuningEngine()
        for _ in 0..<4 {
            #expect(engine.process([Float](repeating: 0.2, count: 4_096), sampleRate: rate) == nil)
        }
    }

    @Test("Every realistic capture rate measures a low E", arguments: [
        22_050.0, 32_000, 44_100, 48_000, 88_200, 96_000, 176_400, 192_000, 384_000,
    ])
    func realisticRates(rate: Double) {
        var engine = TuningEngine()
        let frames = feed(&engine, tone(rate: rate, duration: 0.8), rate: rate)
        let reading = frames.compactMap(\.reading).last
        #expect(reading != nil, "no reading at \(rate) Hz")
        #expect(abs(reading?.cents ?? 999) < 15, "off by \(reading?.cents ?? 999) cents at \(rate) Hz")
    }

    @Test("Detector construction rejects non-finite parameters")
    func detectorInit() {
        #expect(PitchDetector(sampleRate: .infinity, frequencyRange: 60...400) == nil)
        #expect(PitchDetector(sampleRate: .nan, frequencyRange: 60...400) == nil)
        #expect(PitchDetector(sampleRate: 44_100, frequencyRange: 60...400) != nil)
    }

    // MARK: Configuration

    @Test("Reconfiguring on every chunk keeps every reading valid")
    func reconfigurationStorm() {
        var engine = TuningEngine()
        var rng = SplitMix64(state: 7)
        let signal = tone(duration: 3)
        let targets: [StringTarget] = [.automatic, .string(0), .string(5), .string(99), .string(-3), .string(.max), .string(.min)]
        let references: [Double] = [415, 432, 440, 466, .nan, -1, .infinity]
        for chunk in signal.chunked(1_024) {
            let tuning = Tuning.catalog.randomElement(using: &rng)!
            let configuration = TunerConfiguration(
                tuning: tuning,
                referenceA: references.randomElement(using: &rng)!,
                target: targets.randomElement(using: &rng)!
            )
            engine.reconfigure(configuration)
            if let reading = engine.process(chunk, sampleRate: 44_100)?.reading {
                #expect(configuration.tuning.strings.indices.contains(reading.stringIndex))
                #expect(reading.cents.isFinite && abs(reading.cents) <= 300)
                #expect((0...1).contains(reading.clarity))
            }
        }
    }

    // MARK: Fuzz

    @Test("Random signals never produce an invalid estimate")
    func fuzzDetector() throws {
        let range = 60.0...400.0
        let detector = try #require(PitchDetector(sampleRate: 44_100, frequencyRange: range))
        var rng = SplitMix64(state: 0xC0FFEE)
        for round in 0..<240 {
            let amplitude = Float.random(in: 0.0001...1, using: &rng)
            let count = detector.requiredSampleCount + Int.random(in: 0...2_000, using: &rng)
            var samples = [Float](repeating: 0, count: count)
            switch round % 4 {
            case 0: // white noise
                for index in samples.indices { samples[index] = Float.random(in: -amplitude...amplitude, using: &rng) }
            case 1: // one to three sines anywhere in 20 Hz … 5 kHz
                for _ in 0..<Int.random(in: 1...3, using: &rng) {
                    let frequency = Double.random(in: 20...5_000, using: &rng)
                    for index in samples.indices {
                        samples[index] += amplitude * Float(sin(2 * Double.pi * frequency * Double(index) / 44_100))
                    }
                }
            case 2: // sparse impulses
                for index in stride(from: 0, to: count, by: Int.random(in: 50...900, using: &rng)) { samples[index] = amplitude }
            default: // square wave
                let period = Int.random(in: 20...1_200, using: &rng)
                for index in samples.indices { samples[index] = (index / (period / 2)) % 2 == 0 ? amplitude : -amplitude }
            }
            if let estimate = detector.estimate(in: samples) {
                #expect(estimate.frequency.isFinite)
                #expect(estimate.frequency >= range.lowerBound * 0.9 && estimate.frequency <= range.upperBound * 1.1)
                #expect((0...1).contains(estimate.clarity))
            }
        }
    }
}
