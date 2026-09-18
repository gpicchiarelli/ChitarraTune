import Foundation
import Testing
@testable import TunerAudio

/// Smoke tests for the code that talks to the real audio system. They need no microphone and no
/// permission, but they do call Core Audio for real, so they would catch a crash or memory-safety
/// regression in device enumeration (the class of bug that fixed-size buffers used to cause).
@Suite("System audio (no hardware required)")
struct SystemAudioTests {
    @Test("Microphone authorization reports one of the four documented states")
    func authorizationStatus() {
        let status = SystemMicrophoneAuthorization().status()
        #expect([.notDetermined, .authorized, .denied, .restricted].contains(status))
    }

    #if os(macOS)
    @Test("Enumerating inputs is safe and returns unique, named devices")
    func inputEnumeration() {
        for _ in 0..<50 {
            let devices = CoreAudioDevices.inputDevices()
            #expect(Set(devices.map(\.id)).count == devices.count)
            #expect(devices.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty })
        }
    }

    @Test("Unknown device identifiers are rejected, never guessed")
    func unknownDevice() {
        #expect(CoreAudioDevices.deviceID(forUID: "no-such-device-\(UUID().uuidString)") == nil)
        #expect(CoreAudioDevices.name(forUID: "") == nil)
        #expect(SystemAudioInputs().activeInputName(for: .device(id: "no-such-device")) == nil)
    }

    @Test("Every enumerated device can be found again by its UID")
    func roundTrip() {
        for device in CoreAudioDevices.inputDevices() {
            #expect(CoreAudioDevices.deviceID(forUID: device.id) != nil)
            #expect(CoreAudioDevices.name(forUID: device.id) == device.name)
        }
    }

    @Test("Change notifications register and unregister cleanly, repeatedly")
    func listenersComeAndGo() async {
        for _ in 0..<25 {
            let task = Task {
                for await _ in SystemAudioInputs().changes() { break }
            }
            task.cancel()
            await task.value
        }
        _ = SystemAudioInputs().availableInputs()
    }
    #endif
}
