import Foundation
import Testing
@testable import TunerCore

@Suite("TunerCore edges")
struct TunerCoreEdgeTests {
    @Test("Tuning identifiers are their persisted raw values")
    func identifiers() {
        for id in TuningID.allCases { #expect(id.id == id.rawValue) }
        #expect(Tuning.tuning(withRawID: "no-such-tuning").id == .standard)
        for id in TuningID.allCases { #expect(Tuning.tuning(withRawID: id.rawValue) == Tuning.tuning(for: id)) }
    }

    @Test("Resetting a partial filter forgets the previous note")
    func partialFilterReset() throws {
        let filter = try #require(PartialFilter(frequency: 82.41, sampleRate: 44_100))
        let tone = (0..<4_096).map { Float(sin(2 * Double.pi * 82.41 * Double($0) / 44_100)) }
        let silence = [Float](repeating: 0, count: 256)

        _ = filter.process(tone)
        let ringing = filter.process(silence)
        #expect(ringing.contains { abs($0) > 1e-4 }, "an IIR filter keeps ringing after the input stops")

        _ = filter.process(tone)
        filter.reset()
        #expect(filter.process(silence).allSatisfy { $0 == 0 }, "after reset, silence in gives silence out")
    }

    @Test("A partial filter refuses cutoffs it cannot realise")
    func partialFilterLimits() {
        #expect(PartialFilter(frequency: 82.41, sampleRate: .nan) == nil)
        #expect(PartialFilter(frequency: 0, sampleRate: 44_100) == nil)
        #expect(PartialFilter(frequency: 20_000, sampleRate: 44_100) == nil)
    }

    @Test("A tuning the detector cannot hear at this sample rate yields no reading, not a crash")
    func undetectableTuning() {
        // A 8 kHz stream cannot represent a 4 kHz string: neither the detector nor the string filter
        // can be built, and the engine must simply stay silent.
        let tuning = Tuning(id: .standard, strings: [Note(midi: 107)])
        var engine = TuningEngine(configuration: TunerConfiguration(tuning: tuning))
        let noise = (0..<16_000).map { _ in Float.random(in: -0.3...0.3) }
        #expect(stride(from: 0, to: noise.count, by: 1_000).allSatisfy {
            engine.process(Array(noise[$0..<$0 + 1_000]), sampleRate: 8_000) == nil
        })
    }

    @Test("Changing only the pinned string rebuilds the search around the new string")
    func retargetOnly() {
        var engine = TuningEngine(configuration: TunerConfiguration(target: .string(0)))
        let high = (0..<44_100).map { Float(0.3 * sin(2 * Double.pi * Note(midi: 64).frequency() * Double($0) / 44_100)) }
        engine.reconfigure(TunerConfiguration(target: .string(5)))
        let readings = stride(from: 0, to: high.count, by: 1_024).compactMap {
            engine.process(Array(high[$0..<min($0 + 1_024, high.count)]), sampleRate: 44_100)?.reading
        }
        #expect(readings.last?.stringIndex == 5)
        #expect(abs(readings.last?.cents ?? 99) < 5)
    }

    @Test("A tuning always has at least one string", .enabled(if: ProcessInfo.processInfo.environment["SWIFT_TESTING_EXIT_TESTS"] != "0"))
    func emptyTuningTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Tuning(id: .standard, strings: [])
        }
    }
}
