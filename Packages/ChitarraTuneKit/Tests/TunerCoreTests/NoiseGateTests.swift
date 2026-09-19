import Foundation
import Testing
@testable import TunerCore

@Suite("Noise gate")
struct NoiseGateTests {
    private let p = EngineParameters.standard

    @Test("Starts at the fixed level and learns a quiet room at once")
    func learnsQuietRoom() {
        var gate = NoiseGate(parameters: p)
        #expect(gate.openLevel == p.gateOpenLevel)
        gate.update(level: 0.000_2, elapsed: 0.025)
        #expect(!gate.isOpen)
        #expect(gate.openLevel == 0.000_2 * p.gateNoiseMargin)
        gate.update(level: 0.001, elapsed: 0.025)
        #expect(gate.isOpen, "−60 dBFS in a −74 dBFS room is a note")
    }

    @Test("Never opens below the minimum, never above the fixed level")
    func bounds() {
        var silent = NoiseGate(parameters: p)
        silent.update(level: 0, elapsed: 0.025)
        #expect(silent.openLevel == p.minimumGateLevel)
        var noisy = NoiseGate(parameters: p)
        for _ in 0..<400 { noisy.update(level: 0.003, elapsed: 0.025) }
        #expect(noisy.openLevel == p.gateOpenLevel)
        #expect(!noisy.isOpen)
    }

    @Test("Hysteresis: closes below the scaled close level only")
    func hysteresis() {
        var gate = NoiseGate(parameters: p)
        gate.update(level: 0.000_1, elapsed: 0.025)      // opens at 0.0006 (the minimum)
        gate.update(level: 0.000_7, elapsed: 0.025)
        #expect(gate.isOpen)
        gate.update(level: 0.000_4, elapsed: 0.025)      // closes below 0.0006 × 0.625 = 0.000375
        #expect(gate.isOpen)
        gate.update(level: 0.000_3, elapsed: 0.025)
        #expect(!gate.isOpen)
    }

    @Test("The floor stands still while a note sounds, and rises no faster than documented")
    func floorRate() {
        var gate = NoiseGate(parameters: p)
        gate.update(level: 0.000_2, elapsed: 0.025)
        for _ in 0..<200 { gate.update(level: 0.002, elapsed: 0.025) }    // 5 s of a note
        #expect(gate.noiseFloor == 0.000_2)
        var rising = NoiseGate(parameters: p)
        rising.update(level: 0.000_1, elapsed: 0.025)
        rising.update(level: 0.000_12, elapsed: 1)                         // the room got louder
        #expect(abs(20 * log10(rising.noiseFloor / 0.000_1) - 1.58) < 0.01, "follows at once up to the new level")
        rising.update(level: 0.000_3, elapsed: 1)
        #expect(abs(20 * log10(rising.noiseFloor / 0.000_12) - p.noiseFloorRise) < 1e-9, "then 3 dB per second")
    }
}

@Suite("Inharmonicity tracker")
struct InharmonicityTrackerTests {
    @Test("Seeds from the first measurement, averages later ones, keeps its value without one")
    func averaging() {
        var tracker = InharmonicityTracker()
        #expect(tracker.known(for: 0) == nil)
        let seeded = tracker.update(measured: 100 * pow(2, -4 / 1_200), estimate: 100, string: 0, weight: 0.5)
        #expect(abs(seeded + 4) < 1e-9)
        let averaged = tracker.update(measured: 100 * pow(2, -2 / 1_200), estimate: 100, string: 0, weight: 0.5)
        #expect(abs(averaged + 3) < 1e-9)
        #expect(tracker.update(measured: nil, estimate: 100, string: 0, weight: 0.5) == averaged)
        #expect(tracker.known(for: 0) == averaged)
        #expect(tracker.known(for: 1) == nil)
    }

    @Test("A new string starts afresh, at zero if it cannot be measured yet")
    func newString() {
        var tracker = InharmonicityTracker()
        _ = tracker.update(measured: 99, estimate: 100, string: 0, weight: 0.5)
        #expect(tracker.update(measured: nil, estimate: 200, string: 3, weight: 0.5) == 0)
        #expect(tracker.known(for: 0) == nil)
    }
}
