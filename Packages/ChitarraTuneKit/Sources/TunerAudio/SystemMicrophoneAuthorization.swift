import AVFoundation

/// Microphone permission backed by `AVCaptureDevice` (works identically on macOS and iOS).
///
/// The call that can show the system prompt, ``request()``, lives in `Hardware/MicrophonePrompt.swift`.
public struct SystemMicrophoneAuthorization: MicrophoneAuthorizing {
    public init() {}

    public func status() -> MicrophoneAuthorization {
        Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// Maps the system status. Unknown future values are treated as denied: never assume access.
    static func map(_ status: AVAuthorizationStatus) -> MicrophoneAuthorization {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}
