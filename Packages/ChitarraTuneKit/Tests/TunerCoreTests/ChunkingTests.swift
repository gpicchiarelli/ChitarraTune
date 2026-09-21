import Foundation
import Testing
@testable import TunerCore

/// How a device slices audio into callbacks (20 ms on one Mac, 100 ms on another, irregular on a USB
/// interface) is not a property of the guitar, so it must not change the measurement: not the
/// readings, not the in-tune decision, not how long a reading is held.
@Suite("Chunking invariance")
struct ChunkingTests {
    /// A plucked string that settles, then silence long enough for the hold to expire.
    private static func performance(rate: Double) -> [Float] {
        let f0 = Tuning.standard.strings[1].frequency() * pow(2, -3.0 / 1200)
        return StringModel().pluck(frequency: f0, sampleRate: rate, duration: 1.6) + SignalGenerator.silence(count: Int(rate))
    }

    /// The last frame produced inside each consecutive `segment`-sample stretch, feeding the stretch in
    /// chunks whose sizes cycle through `sizes`. Every stretch spans several hops, so it contains at
    /// least one analysis once the window is full, and the last one falls at a fixed sample position.
    private static func checkpoints(_ signal: [Float], rate: Double, segment: Int, sizes: [Int]) -> [TunerFrame?] {
        var engine = TuningEngine()
        var next = 0
        return stride(from: 0, to: signal.count, by: segment).map { base in
            var last: TunerFrame?
            var index = base
            let end = min(base + segment, signal.count)
            while index < end {
                let size = sizes[next % sizes.count]
                next += 1
                let stop = min(index + size, end)
                if let frame = engine.process(Array(signal[index..<stop]), sampleRate: rate) { last = frame }
                index = stop
            }
            return last
        }
    }

    @Test("Frames do not depend on the callback size", arguments: [44_100.0, 48_000.0])
    func invariance(rate: Double) throws {
        let signal = Self.performance(rate: rate)
        let segment = Int(rate * 0.1)   // 4 hops
        let reference = Self.checkpoints(signal, rate: rate, segment: segment, sizes: [128])
        // The run must exercise everything that depends on counting hops.
        let readings = reference.compactMap { $0?.reading }
        #expect(readings.contains { $0.isInTune })
        #expect(readings.contains { $0.isHeld })
        #expect(reference.last.flatMap { $0 }?.reading == nil, "the hold must expire in the silent tail")

        for sizes in [[1_024], [4_410], [segment], [17, 1_024, 4_800, 333, 2_048], [8_192]] {
            let frames = Self.checkpoints(signal, rate: rate, segment: segment, sizes: sizes)
            #expect(frames.count == reference.count)
            let first = frames.indices.first { frames[$0] != reference[$0] }
            #expect(first == nil, "chunk sizes \(sizes) @ \(rate) Hz, first difference at checkpoint \(first ?? -1)")
        }
    }

    @Test("A long callback reaches “in tune” after the same audio as short ones")
    func stabilityCountsAnalyses() throws {
        let rate = 48_000.0
        let signal = Self.performance(rate: rate)
        func samplesUntilInTune(chunk: Int) -> Int? {
            var engine = TuningEngine()
            return stride(from: 0, to: signal.count, by: chunk).first { index in
                engine.process(Array(signal[index..<min(index + chunk, signal.count)]), sampleRate: rate)?.reading?.isInTune == true
            }.map { $0 + chunk }
        }
        let short = try #require(samplesUntilInTune(chunk: 256))
        let long = try #require(samplesUntilInTune(chunk: 4_800))
        // The long callback can only report it at the end of the callback in which it happened.
        #expect(long >= short && long - short < 4_800, "short \(short), long \(long)")
    }
}

@Suite("Engine value semantics")
struct EngineValueSemanticsTests {
    /// `TuningEngine` is a struct: a copy must be a second, independent instrument. Before the string
    /// filters became value types a copy shared their state, and feeding one engine corrupted the other.
    @Test("A copied engine measures independently of the original")
    func copiesAreIndependent() throws {
        let rate = 48_000.0
        let low = StringModel().pluck(frequency: 82.41, sampleRate: rate, duration: 1)
        let high = StringModel().pluck(frequency: 329.63, sampleRate: rate, duration: 1)
        var original = TuningEngine()
        for chunk in Array(low.prefix(24_000)).chunked(1_024) { _ = original.process(chunk, sampleRate: rate) }

        var reference = original    // continues with the same audio
        var other = original        // hears something else
        for chunk in high.chunked(1_024) { _ = other.process(chunk, sampleRate: rate) }
        let rest = Array(low.dropFirst(24_000)).chunked(1_024)
        let expected = rest.compactMap { reference.process($0, sampleRate: rate) }
        let actual = rest.compactMap { original.process($0, sampleRate: rate) }
        #expect(actual == expected)
        #expect(try #require(actual.last?.reading).stringIndex == 0)
    }

    /// Two windows on one Mac are two engines analysing in turn, chunk after chunk. Sequentially the
    /// detector's scratch happens to be rewritten between them; interleaved, anything either of them
    /// kept between calls would land in the other's analysis. `TuningEngine` takes a detector of its
    /// own the first time a copy is used, so the interleaved readings are the sequential ones.
    @Test("Two engines interleaved read exactly as two engines alone")
    func interleavedCopiesDoNotShare() throws {
        let rate = 48_000.0
        let low = StringModel().pluck(frequency: 82.41, sampleRate: rate, duration: 1).chunked(1_024)
        let high = StringModel().pluck(frequency: 329.63, sampleRate: rate, duration: 1).chunked(1_024)

        var seed = TuningEngine()
        for chunk in low.prefix(4) { _ = seed.process(chunk, sampleRate: rate) }

        var alone = seed, other = seed
        let aloneFrames = low.dropFirst(4).compactMap { alone.process($0, sampleRate: rate) }
        _ = high.map { other.process($0, sampleRate: rate) }

        var first = seed, second = seed
        var interleaved: [TunerFrame] = []
        for (a, b) in zip(low.dropFirst(4), high) {
            if let frame = first.process(a, sampleRate: rate) { interleaved.append(frame) }
            _ = second.process(b, sampleRate: rate)
        }
        #expect(interleaved == aloneFrames)
    }
}
