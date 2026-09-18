import Foundation
import Synchronization
import TunerAudio
import TunerCore
@testable import TunerFeature

/// Capture backend the test drives by hand.
final class MockCapture: AudioCapturing {
    private struct State {
        var starts = 0
        var stops = 0
        var lastInput: AudioInputSelection?
        var startFailure: CaptureFailure?
        var continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation?
    }

    private let state = Mutex(State())
    private let holdsNextStart = Mutex(false)
    private let heldStart = Mutex<CheckedContinuation<Void, Never>?>(nil)

    /// The next `start` suspends until ``releaseStart()``, like a slow audio device.
    func holdNextStart() { holdsNextStart.withLock { $0 = true } }
    var isHoldingStart: Bool { heldStart.withLock { $0 != nil } }
    func releaseStart() { heldStart.withLock { $0?.resume(); $0 = nil } }

    var startCount: Int { state.withLock { $0.starts } }
    var stopCount: Int { state.withLock { $0.stops } }
    var lastInput: AudioInputSelection? { state.withLock { $0.lastInput } }

    func failNextStart(with failure: CaptureFailure?) { state.withLock { $0.startFailure = failure } }

    func start(input: AudioInputSelection) async throws(CaptureFailure) -> AsyncThrowingStream<AudioChunk, any Error> {
        if holdsNextStart.withLock({ held in defer { held = false }; return held }) {
            await withCheckedContinuation { continuation in heldStart.withLock { $0 = continuation } }
        }
        let (stream, continuation) = AsyncThrowingStream<AudioChunk, any Error>.makeStream()
        let failure: CaptureFailure? = state.withLock {
            $0.starts += 1
            $0.lastInput = input
            let failure = $0.startFailure
            if failure == nil { $0.continuation = continuation }
            return failure
        }
        if let failure { throw failure }
        return stream
    }

    func stop() async {
        let continuation = state.withLock { state -> AsyncThrowingStream<AudioChunk, any Error>.Continuation? in
            state.stops += 1
            defer { state.continuation = nil }
            return state.continuation
        }
        continuation?.finish()
    }

    func send(_ samples: [Float], sampleRate: Double = 44_100) {
        _ = state.withLock { $0.continuation }?.yield(AudioChunk(samples: samples, sampleRate: sampleRate))
    }

    func fail(with failure: CaptureFailure) {
        state.withLock { $0.continuation }?.finish(throwing: failure)
    }
}

/// Input list that tests can change at runtime.
final class MutableInputs: AudioInputProviding {
    private let devices = Mutex<[AudioInputDevice]>([])
    private let stream = AsyncStream<Void>.makeStream()
    private let resumption = AsyncStream<Void>.makeStream()

    init(_ devices: [AudioInputDevice] = []) { self.devices.withLock { $0 = devices } }

    func set(_ newValue: [AudioInputDevice]) {
        devices.withLock { $0 = newValue }
        stream.continuation.yield()
    }

    func availableInputs() -> [AudioInputDevice] { devices.withLock { $0 } }

    func activeInputName(for selection: AudioInputSelection) -> String? {
        guard let id = selection.deviceID else { return "Default Mic" }
        return devices.withLock { $0.first { $0.id == id }?.name }
    }

    func changes() -> AsyncStream<Void> { stream.stream }

    /// Simulates the end of a system interruption that allows capture to resume.
    func endInterruption() { resumption.continuation.yield() }

    func resumptions() -> AsyncStream<Void> { resumption.stream }
}

/// Mutable time source for idle-timeout tests.
final class TestClock: Sendable {
    private let offset = Mutex<Duration>(.zero)
    private let origin = ContinuousClock.now

    var now: ContinuousClock.Instant { origin.advanced(by: offset.withLock { $0 }) }
    func advance(by duration: Duration) { offset.withLock { $0 += duration } }
}

/// Polls until `condition` holds; fails the test with a clear message on timeout.
@MainActor
func eventually(
    timeout: Duration = .seconds(5),
    _ message: @autoclosure () -> String = "condition not met in time",
    _ condition: @MainActor () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

@MainActor
func makeSettings(_ name: String = #function) -> TunerSettings {
    let suite = "test.\(name).\(UUID().uuidString)"
    return TunerSettings(defaults: UserDefaults(suiteName: suite)!)
}

func pluckSamples(midi: Int, cents: Double = 0, duration: Double = 0.1, amplitude: Double = 0.3) -> [Float] {
    let frequency = Note(midi: midi).frequency() * pow(2, cents / 1200)
    let count = Int(duration * 44_100)
    let harmonics: [Double] = [1, 0.6, 0.4, 0.25, 0.15]
    let norm = harmonics.reduce(0, +)
    return (0..<count).map { n in
        let t = Double(n) / 44_100
        let value = harmonics.enumerated().reduce(0.0) { $0 + $1.element * sin(2 * .pi * frequency * Double($1.offset + 1) * t) }
        return Float(amplitude * value / norm)
    }
}
