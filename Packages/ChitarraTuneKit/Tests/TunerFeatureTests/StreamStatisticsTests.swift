import Foundation
import Testing
import TunerAudio
import TunerCore
@testable import TunerFeature

@Suite("Stream statistics")
struct StreamStatisticsTests {
    private func chunks(_ samples: [Float], size: Int = 1_024, rate: Double = 44_100, from start: Int64 = 0) -> [AudioChunk] {
        stride(from: 0, to: samples.count, by: size).map {
            AudioChunk(samples: Array(samples[$0..<min($0 + size, samples.count)]), sampleRate: rate, sampleTime: start + Int64($0))
        }
    }

    // MARK: Stream statistics

    @Test("Statistics describe what the device delivered")
    func statistics() {
        var stats = StreamStatistics()
        #expect(stats.duration == 0 && stats.averageChunkDuration == 0 && stats.analysisRate == 0)
        stats.record(AudioChunk(samples: .init(repeating: 0, count: 4_800), sampleRate: 48_000), analyses: 4, discontinuities: 0)
        stats.record(AudioChunk(samples: .init(repeating: 0, count: 2_400), sampleRate: 48_000), analyses: 2, discontinuities: 1)
        #expect(stats.chunks == 2 && stats.samples == 7_200)
        #expect(stats.smallestChunk == 2_400 && stats.largestChunk == 4_800)
        #expect(stats.duration == 0.15)
        #expect(stats.averageChunkDuration == 75)
        #expect(stats.analysisRate == 40)
        #expect(stats.discontinuities == 1)
        #expect(stats.summary == "48000 Hz, 0.1 s, 2 callbacks of 2400–4800 frames (75.0 ms average), 40.0 analyses/s, 1 discontinuities")

        stats.record(AudioChunk(samples: .init(repeating: 0, count: 441), sampleRate: 44_100), analyses: 0, discontinuities: 0)
        #expect(stats.chunks == 1 && stats.sampleRate == 44_100, "a new sample rate starts afresh")
    }

    @Test("The processor counts real analyses: one per 25 ms, whatever the callback size", arguments: [256, 1_024, 4_410])
    func processorStatistics(size: Int) async {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        for chunk in chunks(pluckSamples(midi: 45, duration: 4), size: size) { _ = await processor.process(chunk) }
        let stats = await processor.statistics
        #expect(stats.largestChunk == size)
        #expect(abs(stats.analysisRate - 40) < 2, "\(stats.summary)")
        #expect(stats.discontinuities == 0)
    }

    @Test("Lost audio is counted")
    func processorCountsGaps() async {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        let tone = pluckSamples(midi: 45, duration: 0.5)
        for chunk in chunks(tone) + chunks(tone, from: 100_000) { _ = await processor.process(chunk) }
        #expect(await processor.statistics.discontinuities == 1)
    }

    @Test("Statistics are reported at the end of a stream")
    func reportAtEnd() async throws {
        let processor = TunerProcessor(configuration: TunerConfiguration(), parameters: .standard)
        let (input, feed) = AsyncThrowingStream<AudioChunk, any Error>.makeStream()
        let frames = processor.frames(from: input)
        for chunk in chunks(pluckSamples(midi: 45, duration: 3.5)) { feed.yield(chunk) }
        feed.finish()
        for try await _ in frames {}
        #expect(await processor.statistics.duration > TunerProcessor.firstReport)
    }
}
