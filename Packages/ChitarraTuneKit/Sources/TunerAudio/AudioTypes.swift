import Foundation

/// A block of mono audio, as delivered by a capture backend.
public struct AudioChunk: Sendable {
    public let samples: [Float]
    /// Sample rate of `samples` in hertz.
    public let sampleRate: Double
    /// Position of the first sample on the device's timeline, when the backend knows it. Consecutive
    /// chunks are contiguous when each starts where the previous one ended; a jump means audio was
    /// lost (a dropped buffer, an overloaded consumer) and the analysis history must be discarded.
    public let sampleTime: Int64?

    public init(samples: [Float], sampleRate: Double, sampleTime: Int64? = nil) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.sampleTime = sampleTime
    }
}

/// An audio input the user can pick (built-in microphone, USB interface, headset…).
public struct AudioInputDevice: Sendable, Hashable, Identifiable {
    /// Stable, persistent identifier (Core Audio device UID / `AVAudioSessionPortDescription.uid`).
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Which input capture should use.
public enum AudioInputSelection: Sendable, Hashable {
    case systemDefault
    case device(id: String)

    public var deviceID: String? {
        if case .device(let id) = self { id } else { nil }
    }
}

/// Reasons capture can fail or end. Deliberately free of UI text: the app layer localises them.
public enum CaptureFailure: Error, Sendable, Hashable {
    case microphoneDenied
    case microphoneRestricted
    /// No usable input device / route.
    case noInputAvailable
    /// The chosen device disappeared or cannot be opened.
    case inputUnavailable
    /// The audio engine refused to start (`OSStatus` / `NSError` code for diagnostics).
    case engineFailed(code: Int)
    /// The system interrupted capture (phone call, Siri, another app took the microphone).
    case interrupted
    /// The audio route or hardware format changed; capture can simply be restarted.
    case configurationChanged

    /// Maps any error thrown by a capture stream to a failure; unknown errors become
    /// ``engineFailed(code:)`` with the underlying `NSError` code.
    public init(_ error: any Error) {
        self = (error as? CaptureFailure) ?? .engineFailed(code: (error as NSError).code)
    }
}

/// Backend that turns a microphone into a stream of ``AudioChunk``s.
///
/// Implementations must be safe to call from any isolation domain. The returned stream ends
/// normally after ``stop()`` and finishes throwing a ``CaptureFailure`` if capture dies on its own
/// (`AsyncThrowingStream` cannot carry a typed failure, so use ``CaptureFailure/init(_:)`` to
/// map whatever error the consumer catches).
public protocol AudioCapturing: Sendable {
    func start(input: AudioInputSelection) async throws(CaptureFailure) -> AsyncThrowingStream<AudioChunk, any Error>
    func stop() async
}

// MARK: - Permission

public enum MicrophoneAuthorization: Sendable, Hashable {
    case notDetermined, authorized, denied, restricted
}

public protocol MicrophoneAuthorizing: Sendable {
    func status() -> MicrophoneAuthorization
    /// Presents the system prompt if needed. Returns `true` when access is granted.
    func request() async -> Bool
}

// MARK: - Input catalogue

public protocol AudioInputProviding: Sendable {
    func availableInputs() -> [AudioInputDevice]
    /// Name of the input that will be used for `selection` right now.
    func activeInputName(for selection: AudioInputSelection) -> String?
    /// Emits whenever the list of inputs or the default input may have changed.
    /// The stream is event-driven (no polling) and stops observing when its consumer ends.
    func changes() -> AsyncStream<Void>
    /// Emits when a system interruption (phone call, Siri, an alarm) has ended and the system says
    /// capture may resume. Platforms without interruptions return a stream that finishes at once.
    func resumptions() -> AsyncStream<Void>
}

extension AudioInputProviding {
    public func resumptions() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
