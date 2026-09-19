import AVFoundation
import os

/// `AVAudioEngine`-based microphone capture, shared by macOS and iOS.
///
/// Design notes (power and latency):
/// - The tap asks for 1 024 frames (~23 ms). The system may deliver larger buffers (manual rendering
///   delivers ~100 ms); that only lowers how often the screen updates, because the engine analyses at
///   fixed positions in the stream whatever the chunk size.
/// - On iOS the session uses `.record` + `.measurement`, which turns off system gain control and
///   voice processing (less DSP work, untouched signal) and a long I/O buffer duration.
/// - The stream buffers only the newest chunks: a slow consumer never accumulates a backlog.
/// - Everything not needed is torn down in ``stop()``; nothing runs while the tuner is idle.
///
/// Everything here is tested with an engine in manual rendering mode fed with a synthetic signal.
/// The calls that need real hardware (audio session, device routing, starting the engine) are in
/// `Hardware/EngineAudioCapture+System.swift`.
public actor EngineAudioCapture: AudioCapturing {
    static let logger = TunerLog.capture
    /// Frames per tap callback.
    private static let tapFrames: AVAudioFrameCount = 1_024

    private var engine: AVAudioEngine?
    private var continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation?
    private var observers: [any NSObjectProtocol] = []
    /// Identifies the running session. A stream's `onTermination` may fire late (after a newer
    /// session has started), so it must only tear down the session it belongs to.
    private var sessionToken: UUID?

    private let makeEngine: @Sendable () -> AVAudioEngine

    /// `makeEngine` builds the engine for each session: the system's (see `init()` in
    /// `Hardware/EngineAudioCapture+System.swift`) or, in tests, one in manual rendering mode.
    init(makeEngine: @escaping @Sendable () -> AVAudioEngine) {
        self.makeEngine = makeEngine
    }

    public func start(
        input selection: AudioInputSelection
    ) async throws(CaptureFailure) -> AsyncThrowingStream<AudioChunk, any Error> {
        await stop()

        try Self.configureSession(for: selection)

        let engine = makeEngine()
        let inputNode = engine.inputNode
        #if os(macOS)
        try Self.route(inputNode, to: selection)
        #endif

        let format = inputNode.outputFormat(forBus: 0)
        try Self.requireInput(format)
        let sampleRate = format.sampleRate

        let (stream, continuation) = AsyncThrowingStream<AudioChunk, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        // Runs on the audio thread: copy the active channel out of the buffer and hand it over. On an
        // audio interface the guitar is rarely in channel 0, so the selector follows the loudest one.
        // Nothing here touches actor state.
        let selector = ChannelSelector()
        inputNode.installTap(onBus: 0, bufferSize: Self.tapFrames, format: format) { buffer, when in
            if let chunk = selector.chunk(from: buffer, sampleRate: sampleRate, sampleTime: Self.sampleTime(of: when)) {
                continuation.yield(chunk)
            }
        }

        try Self.startEngine(engine)

        let token = UUID()
        self.engine = engine
        self.continuation = continuation
        self.sessionToken = token
        continuation.onTermination = { [weak self] _ in
            Task { await self?.teardown(ifCurrent: token) }
        }
        observeRouteChanges(engine: engine)
        Self.logger.info("capture started @ \(sampleRate, format: .fixed(precision: 0)) Hz")
        return stream
    }

    public func stop() async {
        let continuation = self.continuation
        teardown()
        continuation?.finish()
    }

    // MARK: - Lifecycle

    private func teardown(ifCurrent token: UUID) {
        guard sessionToken == token else { return }
        teardown()
    }

    private func teardown() {
        sessionToken = nil
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers.removeAll()
        continuation = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
            Self.logger.info("capture stopped")
        }
        Self.releaseSession()
    }

    private func fail(_ failure: CaptureFailure) {
        let continuation = self.continuation
        teardown()
        continuation?.finish(throwing: failure)
    }

    private func observeRouteChanges(engine: AVAudioEngine) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            Task { await self?.fail(.configurationChanged) }
        })
        #if os(iOS)
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: nil
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { await self?.fail(.interrupted) }
        })
        // The media server crashed and was restarted: every audio object is stale. Restarting builds
        // a fresh engine and session, which is exactly what a configuration change does.
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { await self?.fail(.configurationChanged) }
        })
        #endif
    }

    /// The device timeline position of a tap buffer, when the engine provides one.
    nonisolated static func sampleTime(of time: AVAudioTime) -> Int64? {
        time.isSampleTimeValid ? time.sampleTime : nil
    }
}
