import AVFoundation
import Foundation
import Synchronization
import Testing
@testable import TunerAudio
import TunerCore
@testable import TunerFeature

@MainActor
@Suite("Lifecycle edges")
struct LifecycleEdgeTests {
    private func model(_ capture: MockCapture, power: PowerSource = .system, auth: FixedMicrophoneAuthorization = .init()) -> TunerModel {
        TunerModel(settings: makeSettings(), capture: capture, authorization: auth, inputs: MutableInputs(), power: power)
    }

    @Test("Stopping while the audio device is still starting releases it and stays idle")
    func stopDuringSlowStart() async {
        let capture = MockCapture()
        capture.holdNextStart()
        let tuner = model(capture)
        let starting = Task { await tuner.start() }
        #expect(await eventually { capture.isHoldingStart })
        await tuner.stop()
        capture.releaseStart()
        await starting.value
        #expect(tuner.status == .idle)
        #expect(!tuner.isListening)
        #expect(capture.stopCount == 2, "the late session must be stopped as well")
    }

    @Test("A steady in-tune string sets isInTune")
    func inTune() async {
        let capture = MockCapture()
        let tuner = model(capture, power: PowerSource(current: { .standard }, changes: { AsyncStream { _ in } }))
        #expect(!tuner.isInTune)
        await tuner.start()
        let signal = pluckSamples(midi: 40, duration: 1.5)
        var reached = false
        for start in stride(from: 0, to: signal.count, by: 1_024) {
            capture.send(Array(signal[start..<min(start + 1_024, signal.count)]))
            if await eventually(timeout: .milliseconds(50)) { tuner.isInTune } { reached = true; break }
        }
        #expect(reached)
        #expect(tuner.isInTune == (tuner.tuneState == .inTune))
        await tuner.stop()
    }

    @Test("A power-state change switches the analysis profile while monitoring")
    func powerProfileFollowsTheDevice() async {
        let profile = Mutex(PowerProfile.standard)
        let (changes, notify) = AsyncStream<Void>.makeStream()
        let power = PowerSource(current: { profile.withLock { $0 } }, changes: { changes })
        let tuner = model(MockCapture(), power: power)
        #expect(tuner.powerProfile == .standard)
        let monitor = Task { await tuner.monitorEnvironment() }
        profile.withLock { $0 = .efficient }
        notify.yield()
        #expect(await eventually { tuner.powerProfile == .efficient })
        notify.yield() // unchanged profile: nothing to do
        profile.withLock { $0 = .standard }
        notify.yield()
        #expect(await eventually { tuner.powerProfile == .standard })
        monitor.cancel()
        notify.finish()
    }
}

@Suite("Power profile")
struct PowerProfileRuleTests {
    @Test("Efficient in Low Power Mode or under serious thermal pressure", arguments: [
        (false, ProcessInfo.ThermalState.nominal, PowerProfile.standard),
        (false, .fair, .standard),
        (false, .serious, .efficient),
        (false, .critical, .efficient),
        (true, .nominal, .efficient),
        (true, .critical, .efficient),
    ])
    func rule(lowPower: Bool, thermal: ProcessInfo.ThermalState, expected: PowerProfile) {
        #expect(PowerProfile.profile(lowPowerMode: lowPower, thermalState: thermal) == expected)
    }

    @Test("The device's current state maps through the same rule")
    func current() {
        let info = ProcessInfo.processInfo
        #expect(PowerProfile.current() == PowerProfile.profile(lowPowerMode: info.isLowPowerModeEnabled, thermalState: info.thermalState))
        #expect(PowerSource.system.current() == PowerProfile.current())
    }

    @Test("Low Power Mode and thermal notifications are both reported", arguments: [
        Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification,
    ])
    func notifications(name: Notification.Name) async {
        // The stream registers its observers while it is created, so a post right after is not lost.
        var changes = PowerSource.system.changes().makeAsyncIterator()
        NotificationCenter.default.post(name: name, object: nil)
        #expect(await changes.next() != nil)
    }
}

@MainActor
@Suite("Live wiring")
struct LiveWiringTests {
    @Test("The live hub builds real-system models without touching the microphone")
    func liveHub() {
        let hub = TunerHub.live(settings: makeSettings())
        let model = hub.primary
        #expect(model.status == .idle)
        #expect(hub.model(for: hub.primaryID) === model)
    }
}

@Suite("Audio plumbing without hardware")
struct AudioPlumbingTests {
    @Test("Permission states map one to one; unknown future states count as denied", arguments: [
        (AVAuthorizationStatus.authorized, MicrophoneAuthorization.authorized),
        (.denied, .denied), (.restricted, .restricted), (.notDetermined, .notDetermined),
    ])
    func permissionMapping(system: AVAuthorizationStatus, expected: MicrophoneAuthorization) {
        #expect(SystemMicrophoneAuthorization.map(system) == expected)
    }

    @Test("An unknown permission value is never read as access")
    func unknownPermission() throws {
        let future = try #require(AVAuthorizationStatus(rawValue: 99))
        #expect(SystemMicrophoneAuthorization.map(future) == .denied)
    }

    @Test("A tap buffer becomes a chunk of the loudest channel, at the device rate")
    func bufferToChunk() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
        buffer.frameLength = 64
        let data = try #require(buffer.floatChannelData)
        for frame in 0..<64 { data[0][frame] = 0; data[1][frame] = Float(frame) / 64 }
        let chunk = try #require(ChannelSelector().chunk(from: buffer, sampleRate: 48_000))
        #expect(chunk.sampleRate == 48_000)
        #expect(chunk.samples == (0..<64).map { Float($0) / 64 })
    }

    @Test("Empty or non-float buffers produce no chunk")
    func emptyBuffers() throws {
        let float = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let empty = try #require(AVAudioPCMBuffer(pcmFormat: float, frameCapacity: 16))
        #expect(ChannelSelector().chunk(from: empty, sampleRate: 44_100) == nil)

        let integer = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44_100, channels: 1, interleaved: false))
        let ints = try #require(AVAudioPCMBuffer(pcmFormat: integer, frameCapacity: 16))
        ints.frameLength = 16
        #expect(ChannelSelector().chunk(from: ints, sampleRate: 44_100) == nil)
    }

    #if os(macOS)
    @Test("The system default input has a name whenever an input exists")
    func defaultInputName() {
        let name = SystemAudioInputs().activeInputName(for: .systemDefault)
        if CoreAudioDevices.inputDevices().isEmpty { return }
        #expect(name.map { !$0.isEmpty } == true)
    }
    #endif
}

@MainActor
@Suite("Demo isolation")
struct DemoIsolationTests {
    @Test("Demo defaults are a separate, emptied suite")
    func demoSuite() {
        let defaults = TunerHub.demoDefaults(suite: "test.demo.\(UUID().uuidString)")
        #expect(defaults !== UserDefaults.standard)
        #expect(defaults.dictionaryRepresentation()["A4"] == nil || defaults.object(forKey: "A4") == nil)
    }

    @Test("A reserved suite name falls back to a private suite, never to the real preferences")
    func reservedSuite() throws {
        // Guard: only run the fallback if the system really refuses this name, so nothing is ever
        // removed from the global domain.
        try #require(UserDefaults(suiteName: UserDefaults.globalDomain) == nil)
        let defaults = TunerHub.demoDefaults(suite: UserDefaults.globalDomain)
        #expect(defaults !== UserDefaults.standard)
        defaults.set(1, forKey: "probe")
        #expect(UserDefaults.standard.object(forKey: "probe") == nil)
        defaults.removeObject(forKey: "probe")
    }
}
