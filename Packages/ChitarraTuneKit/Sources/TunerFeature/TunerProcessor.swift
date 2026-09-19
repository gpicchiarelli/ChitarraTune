import Foundation
import os
import TunerAudio
import TunerCore

/// Runs the whole audio loop off the main actor: it reads the capture stream, feeds the
/// (non-`Sendable`) ``TuningEngine`` and hands back only the resulting ``TunerFrame``s.
///
/// Audio never waits for the main thread. If the UI falls behind, it misses *frames* (only the newest
/// is kept), never samples, so the analysis history stays contiguous. All engine access is serialised
/// by actor isolation; no locks or `@unchecked Sendable`.
actor TunerProcessor {
    private var engine: TuningEngine
    private var configuration: TunerConfiguration
    private var parameters: EngineParameters
    private let signposter = TunerLog.signposter

    init(configuration: TunerConfiguration, parameters: EngineParameters) {
        self.configuration = configuration
        self.parameters = parameters
        engine = TuningEngine(configuration: configuration, parameters: parameters)
    }

    /// Applies the user's current configuration. New parameters (a power-profile change) need a new
    /// engine; a new tuning, A4 or target is a reconfiguration.
    func update(configuration: TunerConfiguration, parameters: EngineParameters) {
        if parameters != self.parameters {
            self.parameters = parameters
            engine = TuningEngine(configuration: configuration, parameters: parameters)
        } else {
            engine.reconfigure(configuration)
        }
        self.configuration = configuration
    }

    /// Analyses `chunks` on this actor and returns the frames. The stream ends when the capture ends,
    /// and rethrows the capture's failure.
    nonisolated func frames(from chunks: AsyncThrowingStream<AudioChunk, any Error>) -> AsyncThrowingStream<TunerFrame, any Error> {
        let (frames, continuation) = AsyncThrowingStream<TunerFrame, any Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let loop = Task { await self.run(chunks, into: continuation) }
        continuation.onTermination = { _ in loop.cancel() }
        return frames
    }

    private func run(_ chunks: AsyncThrowingStream<AudioChunk, any Error>, into frames: AsyncThrowingStream<TunerFrame, any Error>.Continuation) async {
        do {
            for try await chunk in chunks {
                if let frame = process(chunk) { frames.yield(frame) }
            }
            frames.finish()
        } catch {
            frames.finish(throwing: error)
        }
        if statistics.chunks > 0 { reportStatistics() }
    }

    func process(_ chunk: AudioChunk) -> TunerFrame? {
        let interval = signposter.beginInterval("analyse")
        defer { signposter.endInterval("analyse", interval) }
        let analyses = engine.analysisCount, discontinuities = engine.discontinuityCount
        let frame = engine.process(chunk.samples, sampleRate: chunk.sampleRate, sampleTime: chunk.sampleTime)
        statistics.record(chunk, analyses: engine.analysisCount - analyses, discontinuities: engine.discontinuityCount - discontinuities)
        if statistics.duration >= nextReport {
            reportStatistics()
            nextReport = ((statistics.duration / Self.reportInterval).rounded(.down) + 1) * Self.reportInterval
        }
        return frame
    }

    // MARK: - Field diagnostics

    /// Seconds of audio after which the stream statistics are first logged, then how often (and once
    /// more when the stream ends).
    static let firstReport = 3.0
    static let reportInterval = 60.0

    /// What the device has delivered so far in this session.
    private(set) var statistics = StreamStatistics()
    private var nextReport = TunerProcessor.firstReport

    private func reportStatistics() {
        TunerLog.capture.notice("stream: \(self.statistics.summary, privacy: .public)")
    }
}
