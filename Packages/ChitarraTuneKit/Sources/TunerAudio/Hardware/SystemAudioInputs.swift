import AVFoundation
#if os(macOS)
import CoreAudio
#endif

/// Lists audio inputs and reports changes without polling.
///
/// - macOS: Core Audio HAL property listeners (device list + default input).
/// - iOS/iPadOS: `AVAudioSession` route-change notifications.
public struct SystemAudioInputs: AudioInputProviding {
    public init() {}

    #if os(macOS)
    public func availableInputs() -> [AudioInputDevice] { CoreAudioDevices.inputDevices() }

    public func activeInputName(for selection: AudioInputSelection) -> String? {
        if let id = selection.deviceID { CoreAudioDevices.name(forUID: id) } else { CoreAudioDevices.defaultInputName() }
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let queue = DispatchQueue(label: "com.chitarratune.audio-inputs", qos: .utility)
            // The block is immutable and Core Audio invokes it on `queue`; it only yields into a
            // thread-safe continuation. It must be kept to unregister the listener.
            nonisolated(unsafe) let block: AudioObjectPropertyListenerBlock = { _, _ in continuation.yield() }
            let system = AudioObjectID(kAudioObjectSystemObject)
            var addresses = [CoreAudioDevices.devicesAddress, CoreAudioDevices.defaultInputAddress]
            for index in addresses.indices {
                AudioObjectAddPropertyListenerBlock(system, &addresses[index], queue, block)
            }
            let registered = addresses
            continuation.onTermination = { _ in
                var addresses = registered
                for index in addresses.indices {
                    AudioObjectRemovePropertyListenerBlock(system, &addresses[index], queue, block)
                }
            }
        }
    }
    #else
    public func availableInputs() -> [AudioInputDevice] {
        let session = AVAudioSession.sharedInstance()
        // `availableInputs` is only populated once the category allows recording.
        if session.category != .record, session.category != .playAndRecord {
            try? session.setCategory(.record, mode: .measurement)
        }
        return (session.availableInputs ?? []).map { AudioInputDevice(id: $0.uid, name: $0.portName) }
    }

    public func activeInputName(for selection: AudioInputSelection) -> String? {
        let session = AVAudioSession.sharedInstance()
        if let id = selection.deviceID {
            return session.availableInputs?.first { $0.uid == id }?.portName
        }
        return session.currentRoute.inputs.first?.portName
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            nonisolated(unsafe) let token = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil
            ) { _ in continuation.yield() }
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }

    public func resumptions() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            nonisolated(unsafe) let token = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: nil
            ) { note in
                if Self.isResumableEnd(note.userInfo) { continuation.yield() }
            }
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }

    /// `true` for an interruption that has ended with the system's "you may resume" hint.
    static func isResumableEnd(_ userInfo: [AnyHashable: Any]?) -> Bool {
        let type = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        let options = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        return type == AVAudioSession.InterruptionType.ended.rawValue
            && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
    }
    #endif
}
