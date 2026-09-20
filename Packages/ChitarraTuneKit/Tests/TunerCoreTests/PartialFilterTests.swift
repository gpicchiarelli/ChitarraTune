import Foundation
import Testing
@testable import TunerCore

@Suite("String filter")
struct PartialFilterTests {
    /// Steady-state gain of the filter for a sine at `frequency`, in decibels.
    private func gain(_ filter: PartialFilter, at frequency: Double, rate: Double) -> Double {
        var filter = filter
        let count = Int(rate)   // one second: every transient has died out by the second half
        let input = (0..<count).map { Float(sin(2 * Double.pi * frequency * Double($0) / rate)) }
        let output = filter.process(input).suffix(count / 2)
        let rms = (output.reduce(0) { $0 + Double($1) * Double($1) } / Double(output.count)).squareRoot()
        return 20 * log10(rms * 2.squareRoot())
    }

    /// The figures promised in the ``PartialFilter`` documentation.
    @Test("Passes the fundamental, attenuates the third partial and rumble, as documented",
          arguments: [(82.41, 44_100.0), (110, 48_000.0), (329.63, 96_000.0), (65.41, 44_100.0), (207.65, 48_000.0)])
    func response(string: Double, rate: Double) throws {
        let filter = try #require(PartialFilter(frequency: string, sampleRate: rate))
        for cents in [-50.0, 0, 50] {
            let f0 = string * pow(2, cents / 1_200)
            #expect(gain(filter, at: f0, rate: rate) > -5, "fundamental \(f0) Hz")
        }
        for cents in [-300.0, 0, 300] {   // the engine's whole capture window around the string
            let f0 = string * pow(2, cents / 1_200)
            #expect(gain(filter, at: 3 * f0, rate: rate) < (cents == 0 ? -21 : -15), "third partial of \(f0) Hz")
        }
        #expect(gain(filter, at: string * 0.2, rate: rate) < -15, "rumble a fifth of the string's frequency")
    }

    @Test("Mains hum inside the band is notched out, except close to the string", arguments: [
        (82.41, [50.0, 60, 100, 120]),          // E2: 69–98 Hz is left alone
        (110, [50.0, 60, 150, 180]),            // A2
        (73.42, [50.0, 60, 100, 120]),          // D2: 62–87 Hz is left alone
        (329.63, [150.0, 180, 200, 240, 250]),  // E4
    ] as [(Double, [Double])])
    func humNotches(string: Double, expected: [Double]) throws {
        #expect(PartialFilter.humNotches(for: string) == expected)
        let filter = try #require(PartialFilter(frequency: string, sampleRate: 48_000))
        for hum in expected {
            #expect(gain(filter, at: hum, rate: 48_000) < -25, "\(hum) Hz hum on a \(string) Hz string")
        }
    }

    @Test("Time constants follow the slowest pole, complex or real")
    func timeConstants() {
        // Complex pair of modulus 0.99: τ = −1 / ln 0.99 ≈ 99.5 samples.
        #expect(abs(PartialFilter.Section.timeConstant(a1: -1.9, a2: 0.99 * 0.99) - 99.499) < 0.01)
        // Real roots 0.9 and 0.5: z² − 1.4 z + 0.45; the slower is 0.9 → τ ≈ 9.49 samples.
        #expect(abs(PartialFilter.Section.timeConstant(a1: -1.4, a2: 0.45) - 9.491) < 0.01)
        // FIR (no feedback) and unstable sections have no meaningful decay.
        #expect(PartialFilter.Section.timeConstant(a1: 0, a2: 0) == 0)
        #expect(PartialFilter.Section.timeConstant(a1: -2.2, a2: 1.1) == 0)
    }

    @Test("The settling time covers the slowest section, the hum notches included")
    func settling() throws {
        let plain = try #require(PartialFilter(frequency: 1_000, sampleRate: 48_000))  // no mains in its band
        let notched = try #require(PartialFilter(frequency: 82.41, sampleRate: 48_000))
        #expect(PartialFilter.humNotches(for: 1_000).isEmpty)
        // A notch at 50 Hz with Q 4 decays with τ = Q / (π · 50 Hz) ≈ 25 ms; five of them ≈ 127 ms.
        #expect((5_800...6_400).contains(notched.settlingSamples), "\(notched.settlingSamples)")
        #expect(plain.settlingSamples < notched.settlingSamples / 10)
    }

    @Test("A copy is an independent filter")
    func valueSemantics() throws {
        var original = try #require(PartialFilter(frequency: 110, sampleRate: 48_000))
        let tone = (0..<4_800).map { Float(sin(2 * Double.pi * 110 * Double($0) / 48_000)) }
        _ = original.process(tone)
        var copy = original
        let silence = [Float](repeating: 0, count: 64)
        let fromCopy = copy.process(silence)
        _ = copy.process(tone)
        #expect(original.process(silence) == fromCopy, "processing the copy must not disturb the original")
    }

    @Test("The output depends only on the samples, not on how they were cut into chunks")
    func chunkingInvariance() throws {
        let rate = 44_100.0
        let signal = StringModel().pluck(frequency: 82.41, sampleRate: rate, duration: 1)
        var reference = try #require(PartialFilter(frequency: 82.41, sampleRate: rate))
        let whole = reference.process(signal)
        for size in [1, 64, 1_000, 4_410] {
            var filter = try #require(PartialFilter(frequency: 82.41, sampleRate: rate))
            let pieces = signal.chunked(size).flatMap { filter.process($0) }
            #expect(pieces == whole, "chunks of \(size)")
        }
    }
}
