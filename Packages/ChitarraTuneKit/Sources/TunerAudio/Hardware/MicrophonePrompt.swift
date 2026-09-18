import AVFoundation

extension SystemMicrophoneAuthorization {
    /// Presents the system permission prompt if needed. Returns `true` when access is granted.
    public func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
