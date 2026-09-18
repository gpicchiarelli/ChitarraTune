import AVFoundation
import os

/// `AVAudioEngine`-based microphone capture, shared by macOS and iOS.
///
/// Design notes (power and latency):
/// - The tap size matches the analysis hop (~23 ms), so the process wakes ~43×/s instead of once
///   per hardware buffer.
/// - On iOS the session uses `.record` + `.measurement`, which turns off system gain control and
///   voice processing (less DSP work, untouched signal) and a long I/O buffer duration.
/// - The stream buffers only the newest chunks: a slow consumer never accumulates a backlog.
/// - Everything not needed is torn down in ``stop()``; nothing runs while the tuner is idle.
public actor EngineAudioCapture: AudioCapturing {
    private static let logger = TunerLog.capture
    /// Frames per tap callback.
    private static let tapFrames: AVAudioFrameCount = 1_024

    private var engine: AVAudioEngine?
    private var continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation?
    private var observers: [any NSObjectProtocol] = []
    /// Identifies the running session. A stream's `onTermination` may fire late (after a newer
    /// session has started), so it must only tear down the session it belongs to.
    private var sessionToken: UUID?

    public init() {}

    public func start(
        input selection: AudioInputSelection
    ) async throws(CaptureFailure) -> AsyncThrowingStream<AudioChunk, any Error> {
        await stop()

        try Self.configureSession(for: selection)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        #if os(macOS)
        try Self.route(inputNode, to: selection)
        #endif

        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw .noInputAvailable }
        let sampleRate = format.sampleRate

        let (stream, continuation) = AsyncThrowingStream<AudioChunk, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        // Runs on the audio thread: copy the active channel out of the buffer and hand it over. On an
        // audio interface the guitar is rarely in channel 0, so the selector follows the loudest one.
        // Nothing here touches actor state.
        let selector = ChannelSelector()
        inputNode.installTap(onBus: 0, bufferSize: Self.tapFrames, format: format) { buffer, when in
            let sampleTime = when.isSampleTimeValid ? when.sampleTime : nil
            if let chunk = selector.chunk(from: buffer, sampleRate: sampleRate, sampleTime: sampleTime) { continuation.yield(chunk) }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            Self.logger.error("engine start failed: \(error.localizedDescription, privacy: .public)")
            throw .engineFailed(code: (error as NSError).code)
        }

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
        #if os(iOS)
        // Give the audio hardware back to the system (lets other apps resume playback).
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
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

    // MARK: - Platform configuration

    private static func configureSession(for selection: AudioInputSelection) throws(CaptureFailure) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            // Long buffers → fewer wake-ups; the analysis window dominates latency anyway.
            try session.setPreferredIOBufferDuration(0.023)
            try session.setActive(true)
            if let id = selection.deviceID {
                guard let port = session.availableInputs?.first(where: { $0.uid == id }) else {
                    throw CaptureFailure.inputUnavailable
                }
                try session.setPreferredInput(port)
            } else {
                try session.setPreferredInput(nil)
            }
        } catch let failure as CaptureFailure {
            throw failure
        } catch {
            logger.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
            throw .engineFailed(code: (error as NSError).code)
        }
        guard session.isInputAvailable else { throw .noInputAvailable }
        #endif
    }

    #if os(macOS)
    private static func route(_ inputNode: AVAudioInputNode, to selection: AudioInputSelection) throws(CaptureFailure) {
        guard let uid = selection.deviceID else { return }
        guard let deviceID = CoreAudioDevices.deviceID(forUID: uid) else { throw .inputUnavailable }
        do {
            try inputNode.auAudioUnit.setDeviceID(deviceID)
        } catch {
            logger.error("cannot select input \(uid, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw .inputUnavailable
        }
    }
    #endif
}
