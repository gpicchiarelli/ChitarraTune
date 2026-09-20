import Foundation
import Testing
@testable import TunerCore

@Suite("Spectrum")
struct SpectrumTests {
    private func sine(_ frequency: Double, amplitude: Double, count: Int = 6_000) -> [Float] {
        (0..<count).map { Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / 44_100)) }
    }

    @Test("A sine's amplitude is measured at its own frequency", arguments: [73.42, 110.0, 329.63])
    func amplitude(frequency: Double) throws {
        let tone = try #require(Spectrum.tone(at: frequency, in: sine(frequency, amplitude: 0.3), sampleRate: 44_100))
        #expect(abs(tone.amplitude - 0.3) < 0.01)
        #expect(abs(tone.rms - 0.3 / 2.squareRoot()) < 0.005)
    }

    @Test("The octave above leaves almost nothing in the fundamental's bin")
    func octaveRejection() throws {
        let tone = try #require(Spectrum.tone(at: 73.42, in: sine(146.83, amplitude: 0.3), sampleRate: 44_100))
        #expect(tone.amplitude < 0.3 * 0.05, "more than −26 dB of leakage from one octave up")
    }

    @Test("Degenerate input gives no measurement")
    func degenerate() {
        #expect(Spectrum.tone(at: 100, in: [], sampleRate: 44_100) == nil)
        #expect(Spectrum.tone(at: 100, in: [0.5], sampleRate: 44_100) == nil)
        #expect(Spectrum.tone(at: 100, in: [0.1, 0.2], sampleRate: 0) == nil)
    }
}
