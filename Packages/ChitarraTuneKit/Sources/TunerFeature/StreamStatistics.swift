import Foundation
import TunerAudio

/// What the capture stream actually delivers on this device: sample rate, callback size, how often
/// the engine analyses, and whether audio was lost. It answers questions no simulator can ("does this
/// iPhone deliver 23 ms or 100 ms callbacks?") and is written to the diagnostics log.
public struct StreamStatistics: Sendable, Equatable {
    public private(set) var sampleRate = 0.0
    public private(set) var chunks = 0
    public private(set) var samples = 0
    public private(set) var smallestChunk = 0
    public private(set) var largestChunk = 0
    public private(set) var analyses = 0
    public private(set) var discontinuities = 0

    public init() {}

    /// Seconds of audio received.
    public var duration: Double { sampleRate > 0 ? Double(samples) / sampleRate : 0 }

    /// Average callback length in milliseconds.
    public var averageChunkDuration: Double { chunks > 0 && sampleRate > 0 ? 1_000 * Double(samples) / Double(chunks) / sampleRate : 0 }

    /// Analyses per second of audio.
    public var analysisRate: Double { duration > 0 ? Double(analyses) / duration : 0 }

    /// Adds one callback and what the engine did with it.
    mutating func record(_ chunk: AudioChunk, analyses: Int, discontinuities: Int) {
        if chunk.sampleRate != sampleRate {
            self = StreamStatistics()
            sampleRate = chunk.sampleRate
        }
        let count = chunk.samples.count
        smallestChunk = chunks == 0 ? count : min(smallestChunk, count)
        largestChunk = max(largestChunk, count)
        chunks += 1
        samples += count
        self.analyses += analyses
        self.discontinuities += discontinuities
    }

    /// One line for the diagnostics log.
    public var summary: String {
        String(
            format: "%.0f Hz, %.1f s, %d callbacks of %d–%d frames (%.1f ms average), %.1f analyses/s, %d discontinuities",
            sampleRate, duration, chunks, smallestChunk, largestChunk, averageChunkDuration, analysisRate, discontinuities
        )
    }
}
