import Foundation

/// Fixed microphone permission. Used by demo mode, previews and tests.
public struct FixedMicrophoneAuthorization: MicrophoneAuthorizing {
    public var current: MicrophoneAuthorization
    public var grantsRequests: Bool

    public init(_ current: MicrophoneAuthorization = .authorized, grantsRequests: Bool = true) {
        self.current = current
        self.grantsRequests = grantsRequests
    }

    public func status() -> MicrophoneAuthorization { current }
    public func request() async -> Bool { grantsRequests }
}

/// Fixed list of inputs. Used by demo mode, previews and tests.
public struct StaticAudioInputs: AudioInputProviding {
    public var devices: [AudioInputDevice]
    public var defaultName: String?

    public init(devices: [AudioInputDevice] = [], defaultName: String? = nil) {
        self.devices = devices
        self.defaultName = defaultName
    }

    public func availableInputs() -> [AudioInputDevice] { devices }

    public func activeInputName(for selection: AudioInputSelection) -> String? {
        if let id = selection.deviceID { devices.first { $0.id == id }?.name } else { defaultName }
    }

    public func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
