import AVFoundation

/// Microphone permission backed by `AVCaptureDevice` (works identically on macOS and iOS).
public struct SystemMicrophoneAuthorization: MicrophoneAuthorizing {
    public init() {}

    public func status() -> MicrophoneAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    public func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
