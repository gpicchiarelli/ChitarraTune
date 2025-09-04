import XCTest
@testable import ChitarraTuneCore

final class PitchDetectorTests: XCTestCase {
    func testDetectsSineE2() {
        let fs: Double = 44_100
        let f: Double = 82.4069 // E2
        let n = 4096
        let samples: [Float] = (0..<n).map { i in
            let t = Double(i) / fs
            return Float(sin(2.0 * .pi * f * t))
        }
        let det = PitchDetector(sampleRate: fs)
        let res = det.estimateFrequency(samples: samples)
        XCTAssertNotNil(res)
        if let r = res {
            XCTAssertGreaterThan(r.clarity, 0.15)
            XCTAssertEqual(r.frequency, f, accuracy: 1.0) // within ~1 Hz
        }
    }

    func testForcedIndexOctaveNormalization() {
        let fs: Double = 44_100
        let f: Double = 164.8138 // E3 (octave above E2)
        let n = 4096
        let samples: [Float] = (0..<n).map { i in
            let t = Double(i) / fs
            return Float(sin(2.0 * .pi * f * t))
        }
        // Standard preset
        let preset = DefaultTuningPresets.first { $0.id == "standard" }!
        // Force low E (index 0). Normalization should bring octave down near E2
        let est = estimatePresetTuning(samples: samples, sampleRate: fs, referenceA: 440.0, preset: preset, forcedIndex: 0)
        XCTAssertNotNil(est)
        if let e = est {
            XCTAssertEqual(e.stringLabel, "E2")
            XCTAssertEqual(e.cents, 0, accuracy: 20) // within 20 cents
        }
    }
}

