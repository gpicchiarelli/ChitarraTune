import Foundation
import TunerCore

/// Deterministic synthetic "guitar" used for demos, screenshots, previews and UI tests.
///
/// It plucks each string of a tuning in turn, slightly detuned, and lets the pitch drift towards
/// the target over a few seconds, so the whole UI (needle, in-tune state, string change) can be
/// exercised without a microphone.
public struct SimulatedAudioCapture: AudioCapturing {
    public struct Script: Sendable {
        public var tuning: Tuning
        public var stringOrder: [Int]
        /// Initial detuning in cents.
        public var startCents: Double
        /// Seconds a pluck takes to settle on the target.
        public var settleDuration: Double
        public var pluckDuration: Double

        public init(
            tuning: Tuning = .standard,
            stringOrder: [Int] = [0, 1, 2, 3, 4, 5],
            startCents: Double = -28,
            settleDuration: Double = 3.2,
            pluckDuration: Double = 4.5
        ) {
            self.tuning = tuning
            self.stringOrder = stringOrder
            self.startCents = startCents
            self.settleDuration = settleDuration
            self.pluckDuration = pluckDuration
        }
    }

    private let script: Script
    private let sampleRate: Double
    private let state = StreamTask()

    public init(script: Script = .init(), sampleRate: Double = 48_000) {
        self.script = script
        self.sampleRate = sampleRate
    }

    public func start(input: AudioInputSelection) async throws(CaptureFailure) -> AsyncThrowingStream<AudioChunk, any Error> {
        await state.cancel()
        let (stream, continuation) = AsyncThrowingStream<AudioChunk, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        let script = self.script
        let sampleRate = self.sampleRate
        let task = Task.detached(priority: .userInitiated) {
            await Self.generate(script: script, sampleRate: sampleRate, into: continuation)
        }
        await state.set(task)
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    public func stop() async { await state.cancel() }

    private actor StreamTask {
        private var task: Task<Void, Never>?
        func set(_ task: Task<Void, Never>) { self.task = task }
        func cancel() { task?.cancel(); task = nil }
    }

    private static func generate(
        script: Script,
        sampleRate: Double,
        into continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation
    ) async {
        let chunkFrames = 1_024
        let chunkDuration = Double(chunkFrames) / sampleRate
        let harmonics: [Double] = [1, 0.6, 0.4, 0.25, 0.15]
        let norm = harmonics.reduce(0, +)
        let order = script.stringOrder.isEmpty ? [0] : script.stringOrder

        var phase = 0.0
        var sampleIndex = 0
        var elapsed = 0.0
        let clock = ContinuousClock()
        let start = clock.now

        while !Task.isCancelled {
            let pluck = Int(elapsed / script.pluckDuration)
            let stringIndex = order[pluck % order.count] % script.tuning.stringCount
            let local = elapsed - Double(pluck) * script.pluckDuration
            let progress = min(1, local / script.settleDuration)
            let cents = script.startCents * (1 - progress) * (1 - progress)
            let base = script.tuning.strings[stringIndex].frequency()
            let frequency = base * pow(2, cents / 1200)

            var samples = [Float](repeating: 0, count: chunkFrames)
            for n in 0..<chunkFrames {
                let t = local + Double(n) / sampleRate
                // Fast attack, slow exponential decay, re-plucked at the start of each cycle.
                let envelope = 0.35 * min(1, t * 200) * exp(-t / 2.4)
                var value = 0.0
                for (h, weight) in harmonics.enumerated() { value += weight * sin(Double(h + 1) * phase) }
                phase += 2 * .pi * frequency / sampleRate
                samples[n] = Float(envelope * value / norm)
            }
            if phase > 2 * .pi * 1_000 { phase.formTruncatingRemainder(dividingBy: 2 * .pi) }
            sampleIndex += chunkFrames
            elapsed = Double(sampleIndex) / sampleRate

            continuation.yield(AudioChunk(samples: samples, sampleRate: sampleRate))
            // Pace the stream in real time.
            let due = start.advanced(by: .seconds(elapsed - chunkDuration))
            try? await clock.sleep(until: due)
        }
        continuation.finish()
    }
}
