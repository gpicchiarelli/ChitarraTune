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
          arguments: [(82.41, 44_100.0), (110, 48_000.0), (329.63, 96_000.0), (65.41, 44_100.0)])
    func response(string: Double, rate: Double) throws {
        for cents in [-300.0, 0, 300] {   // the engine's whole capture window around the string
            let f0 = string * pow(2, cents / 1_200)
            let filter = try #require(PartialFilter(frequency: string, sampleRate: rate))
            #expect(abs(gain(filter, at: f0, rate: rate)) < 1, "fundamental \(f0) Hz")
            let third = try #require(PartialFilter(frequency: string, sampleRate: rate))
            #expect(gain(third, at: 3 * f0, rate: rate) < (cents == 0 ? -21 : -15), "third partial of \(f0) Hz")
        }
        let hum = try #require(PartialFilter(frequency: string, sampleRate: rate))
        #expect(gain(hum, at: string * 0.2, rate: rate) < -15, "rumble a fifth of the string's frequency")
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
