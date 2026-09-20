import Foundation
import Testing
@testable import TunerCore

@Suite("Reference pitch validation")
struct ReferencePitchTests {
    @Test("Values are clamped into the supported range", arguments: [
        (100.0, 415.0), (415.0, 415.0), (440.0, 440.0), (466.0, 466.0), (900.0, 466.0),
        (-5.0, 415.0), (0.0, 415.0), (Double.infinity, 466.0), (-Double.infinity, 415.0),
    ])
    func clamps(input: Double, expected: Double) {
        #expect(PitchMath.validReferenceA(input) == expected)
        #expect(TunerConfiguration(referenceA: input).referenceA == expected)
    }

    @Test("NaN falls back to concert pitch")
    func nan() {
        #expect(PitchMath.validReferenceA(.nan) == PitchMath.standardReferenceA)
        #expect(TunerConfiguration(referenceA: .nan).referenceA == 440)
    }

    /// Regression: a NaN A4 used to pass the clamp and trap with "Range requires
    /// lowerBound <= upperBound" the first time the engine built its search range.
    @Test("An engine configured with NaN A4 still analyses audio", arguments: [
        StringTarget.automatic, StringTarget.string(0),
    ])
    func engineSurvivesNaN(target: StringTarget) {
        var engine = TuningEngine(configuration: TunerConfiguration(referenceA: .nan, target: target))
        let signal = SignalGenerator.tone(
            frequency: Note(midi: 40).frequency(),
            sampleRate: 44_100,
            duration: 0.6,
            harmonics: SignalGenerator.guitarHarmonics,
            amplitude: 0.3
        )
        var readings = 0
        var start = 0
        while start < signal.count {
            let end = min(start + 1_024, signal.count)
            if let reading = engine.process(Array(signal[start..<end]), sampleRate: 44_100)?.reading {
                readings += 1
                #expect(abs(reading.cents) < 20)
            }
            start = end
        }
        #expect(readings > 0)
    }
}
