import AVFoundation
import Foundation
import Synchronization
import Testing
@testable import TunerAudio

/// An `AVAudioEngine` in offline manual rendering mode whose input is a synthetic sine: the real
/// capture code runs (tap, channel selection, conversion, teardown, route changes) without a
/// microphone. The test pulls audio through the engine with `render(_:)`.
///
/// `@unchecked Sendable`: the engine is handed to the capture actor through a `@Sendable` factory, and
/// the test only renders while the actor is idle (between awaited calls), so accesses never overlap.
final class ManualRig: @unchecked Sendable {
    let engine = AVAudioEngine()
    let format: AVAudioFormat
    private let input: AVAudioPCMBuffer
    private let output: AVAudioPCMBuffer
    private let frequency: Double
    private let phase = Mutex(0.0)

    init(frequency: Double = 110, sampleRate: Double = 44_100, channels: AVAudioChannelCount = 1) throws {
        self.frequency = frequency
        format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        input = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096))
        output = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096))
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
        let input = self.input
        let accepted = engine.inputNode.setManualRenderingInputPCMFormat(format) { [weak self] frames in
            self?.fill(Int(frames))
            return UnsafePointer(input.audioBufferList)
        }
        #expect(accepted)
        // The input is only pulled when something downstream renders it; keep it silent at the output.
        try engine.connectNode(engine.inputNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
    }

    /// Synthesises the sine on the last channel only (like a guitar in input 2 of an interface).
    private func fill(_ frames: Int) {
        input.frameLength = AVAudioFrameCount(frames)
        guard let data = input.floatChannelData else { return }
        let channels = Int(format.channelCount)
        phase.withLock { phase in
            for frame in 0..<frames {
                for channel in 0..<channels { data[channel][frame] = 0 }
                data[channels - 1][frame] = Float(0.3 * sin(phase))
                phase += 2 * Double.pi * frequency / format.sampleRate
            }
        }
    }

    /// Renders `frames` through the engine, which pulls the input and fires the tap.
    func render(_ frames: AVAudioFrameCount) throws {
        _ = try engine.renderOffline(frames, to: output)
    }
}

@Suite("EngineAudioCapture (manual rendering, no microphone)", .serialized, .timeLimit(.minutes(1)))
struct EngineCaptureTests {
    /// Renders audio through `rig` until `count` chunks have arrived on `stream`. The engine decides
    /// the tap size (about 100 ms, whatever is requested), so the amount to render is not known upfront.
    private func collect(_ count: Int, from stream: AsyncThrowingStream<AudioChunk, any Error>, rendering rig: ManualRig) async throws -> [AudioChunk] {
        let done = Mutex(false)
        let collector = Task {
            var chunks: [AudioChunk] = []
            for try await chunk in stream {
                chunks.append(chunk)
                if chunks.count == count { break }
            }
            done.withLock { $0 = true }
            return chunks
        }
        for _ in 0..<400 where !done.withLock({ $0 }) {
            try rig.render(512)
            await Task.yield()
        }
        return try await collector.value
    }

    @Test("The input tap delivers contiguous, timestamped chunks of the played signal")
    func deliversAudio() async throws {
        let rig = try ManualRig(frequency: 110)
        let capture = EngineAudioCapture(makeEngine: { rig.engine })
        let stream = try await capture.start(input: .systemDefault)
        let chunks = try await collect(4, from: stream, rendering: rig)
        #expect(chunks.allSatisfy { $0.sampleRate == 44_100 && !$0.samples.isEmpty })
        #expect(chunks.contains { $0.samples.contains { abs($0) > 0.2 } }, "the sine must come through")
        let times = chunks.compactMap(\.sampleTime)
        #expect(times.count == chunks.count, "every chunk carries its sample time")
        // This failed once on a loaded CI runner (run 35528246927) and has never been reproduced:
        // rendering far ahead of the collector does not do it — 400 renders against a stream that
        // keeps the newest 8 chunks still passes, because the collector drains concurrently. So the
        // gap itself is the evidence that is missing. A gap that is an exact multiple of a chunk
        // means chunks were dropped between these two; anything else means something other than a
        // drop, and the numbers below are what tells them apart.
        for (previous, next) in zip(chunks, chunks.dropFirst()) {
            if let start = previous.sampleTime, let following = next.sampleTime {
                let gap = following - start
                let expected = Int64(previous.samples.count)
                #expect(
                    following == start + expected,
                    """
                    chunks must be contiguous: \(start) + \(expected) ≠ \(following)                     (gap \(gap), \(Double(gap) / Double(expected)) chunks;                     sample times \(chunks.map(\.sampleTime)), sizes \(chunks.map(\.samples.count)))
                    """)
            }
        }
        await capture.stop()
        #expect(!rig.engine.isRunning)
    }

    @Test("On a two-channel interface the channel carrying the guitar is captured")
    func picksTheGuitarChannel() async throws {
        let rig = try ManualRig(frequency: 110, channels: 2)
        let capture = EngineAudioCapture(makeEngine: { rig.engine })
        let stream = try await capture.start(input: .systemDefault)
        let chunks = try await collect(2, from: stream, rendering: rig)
        #expect(chunks.allSatisfy { $0.samples.contains { abs($0) > 0.2 } })
        await capture.stop()
    }

    @Test("A route change ends the stream with configurationChanged and stops the engine")
    func routeChange() async throws {
        let rig = try ManualRig()
        let capture = EngineAudioCapture(makeEngine: { rig.engine })
        let stream = try await capture.start(input: .systemDefault)
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: rig.engine)
        await #expect(throws: CaptureFailure.configurationChanged) {
            for try await _ in stream {}
        }
        #expect(!rig.engine.isRunning)
    }

    @Test("Starting again replaces the previous session; a late end of the old stream leaves the new one running")
    func restartIsolation() async throws {
        let first = try ManualRig(), second = try ManualRig()
        let engines = Mutex([first, second])
        let capture = EngineAudioCapture(makeEngine: { engines.withLock { $0.removeFirst().engine } })
        let old = try await capture.start(input: .systemDefault)
        let new = try await capture.start(input: .systemDefault)
        #expect(!first.engine.isRunning, "the first engine is stopped by the second start")
        // Ending the old stream now must not tear down the new session.
        _ = old
        let chunks = try await collect(2, from: new, rendering: second)
        #expect(!chunks.isEmpty)
        #expect(second.engine.isRunning)
        await capture.stop()
        #expect(!second.engine.isRunning)
    }

    @Test("When the consumer stops listening, capture tears itself down")
    func consumerCancels() async throws {
        let rig = try ManualRig()
        let capture = EngineAudioCapture(makeEngine: { rig.engine })
        var stream: AsyncThrowingStream<AudioChunk, any Error>? = try await capture.start(input: .systemDefault)
        stream = nil
        _ = stream
        let deadline = ContinuousClock.now + .seconds(5)
        while rig.engine.isRunning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!rig.engine.isRunning)
    }

    /// Why the capture moved off the deprecated `installTap`: the old form returns nothing and raises
    /// an Objective-C exception when it refuses — a node in the wrong state, a format it will not
    /// take — and an Objective-C exception is not catchable from Swift, so a refused tap took the app
    /// down with it. A node that belongs to no engine is the plainest refusal there is.
    @Test("A tap the node refuses becomes a failure, not a crash")
    func refusedTap() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let thrown = #expect(throws: CaptureFailure.self) {
            try EngineAudioCapture.installTap(on: AVAudioMixerNode(), frames: 1_024, format: format) { _, _ in }
        }
        guard case .engineFailed(let code) = try #require(thrown) else {
            Issue.record("a refused tap must be engineFailed, not \(String(describing: thrown))")
            return
        }
        // The code is the system's, not ours; that it is there at all is the point of the new API.
        #expect(code != 0, "the failure must carry the reason the tap was refused")
    }

    @Test("A tap buffer's time becomes a sample position only when the engine provides one")
    func sampleTimes() {
        #expect(EngineAudioCapture.sampleTime(of: AVAudioTime(sampleTime: 4_410, atRate: 44_100)) == 4_410)
        #expect(EngineAudioCapture.sampleTime(of: AVAudioTime(hostTime: mach_absolute_time())) == nil)
    }

    @Test("Selecting a device that does not exist fails without starting anything")
    func unknownDevice() async throws {
        let rig = try ManualRig()
        let capture = EngineAudioCapture(makeEngine: { rig.engine })
        await #expect(throws: CaptureFailure.inputUnavailable) {
            _ = try await capture.start(input: .device(id: "no-such-device-\(UUID().uuidString)"))
        }
        #expect(!rig.engine.isRunning)
    }
}
