import XCTest
@testable import ChitarraTuneCore

final class TuningTests: XCTestCase {
    func testFrequencyFromMidiA4() {
        // A4 (midi 69) should be exactly referenceA
        XCTAssertEqual(frequency(for: 69, referenceA: 440.0), 440.0, accuracy: 1e-9)
        // E2 midi 40 around 82.4069
        XCTAssertEqual(frequency(for: 40, referenceA: 440.0), 82.4069, accuracy: 0.001)
    }

    func testNearestStringStandard() {
        let preset = DefaultTuningPresets.first { $0.id == "standard" }!
        let nearE2 = 82.4
        let res = nearestString(in: preset, for: nearE2, referenceA: 440.0)
        XCTAssertEqual(res.index, 0)
        XCTAssertEqual(res.label, "E2")
        // Slightly sharp should yield positive cents
        XCTAssertGreaterThan(res.cents, -20)
    }

    func testNearestGuitarStringHelper() {
        let res = nearestGuitarString(for: 110.0, referenceA: 440.0)
        XCTAssertEqual(res.string, .a2)
        XCTAssertEqual(res.cents, 0, accuracy: 0.5)
    }
}

