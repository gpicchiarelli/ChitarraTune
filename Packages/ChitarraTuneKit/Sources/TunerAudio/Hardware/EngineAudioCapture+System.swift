import AVFoundation
import os

/// The parts of capture that only real hardware can exercise: configuring the iOS audio session,
/// routing the input to a specific Core Audio device and starting the engine.
extension EngineAudioCapture {
    /// Capture from the system's audio input.
    public init() {
        self.init(makeEngine: { AVAudioEngine() })
    }

    /// An input without a format means there is no usable input device or route.
    static func requireInput(_ format: AVAudioFormat) throws(CaptureFailure) {
        guard format.sampleRate > 0, format.channelCount > 0 else { throw .noInputAvailable }
    }

    static func startEngine(_ engine: AVAudioEngine) throws(CaptureFailure) {
        do {
            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            logger.error("engine start failed: \(Self.describe(error), privacy: .public)")
            throw .engineFailed(code: (error as NSError).code)
        }
    }

    /// Gives the audio hardware back to the system (lets other apps resume playback). iOS only.
    static func releaseSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            logger.error("audio session release failed: \(Self.describe(error), privacy: .public)")
        }
        #endif
    }

    static func configureSession(for selection: AudioInputSelection) throws(CaptureFailure) {
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
            logger.error("audio session setup failed: \(Self.describe(error), privacy: .public)")
            throw .engineFailed(code: (error as NSError).code)
        }
        guard session.isInputAvailable else { throw .noInputAvailable }
        #endif
    }

    #if os(macOS)
    static func route(_ inputNode: AVAudioInputNode, to selection: AudioInputSelection) throws(CaptureFailure) {
        guard let uid = selection.deviceID else { return }
        guard let deviceID = CoreAudioDevices.deviceID(forUID: uid) else { throw .inputUnavailable }
        do {
            // `auAudioUnit` is deprecated from macOS 27: the unit is now borrowed for the duration of
            // the call instead of being handed out, so it cannot outlive the node.
            try inputNode.withAUAudioUnit { unit in
                try unit.setDeviceID(deviceID)
            }
        } catch {
            logger.error("cannot select input \(uid, privacy: .private): \(Self.describe(error), privacy: .public)")
            throw .inputUnavailable
        }
    }
    #endif
}
