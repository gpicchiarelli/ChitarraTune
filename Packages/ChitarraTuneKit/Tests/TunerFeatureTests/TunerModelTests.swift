import Foundation
import Testing
import TunerAudio
import TunerCore
@testable import TunerFeature

@MainActor
@Suite("TunerModel")
struct TunerModelTests {
    private func makeModel(
        capture: MockCapture = MockCapture(),
        authorization: MicrophoneAuthorization = .authorized,
        grantsRequests: Bool = true,
        inputs: any AudioInputProviding = StaticAudioInputs(),
        clock: TestClock = TestClock(),
        settings: TunerSettings = makeSettings()
    ) -> (TunerModel, MockCapture, TestClock) {
        let model = TunerModel(
            settings: settings,
            capture: capture,
            authorization: FixedMicrophoneAuthorization(authorization, grantsRequests: grantsRequests),
            inputs: inputs,
            now: { clock.now }
        )
        return (model, capture, clock)
    }

    /// Streams a tone until the model shows a reading (or gives up).
    private func feed(_ capture: MockCapture, _ model: TunerModel, midi: Int, cents: Double = 0) async -> Bool {
        let samples = pluckSamples(midi: midi, cents: cents, duration: 0.3)
        for chunk in samples.chunked(1_024) { capture.send(chunk) }
        return await eventually { model.reading != nil }
    }

    // MARK: Permission

    @Test("Denied permission fails without touching the microphone")
    func denied() async {
        let (model, capture, _) = makeModel(authorization: .denied)
        await model.start()
        #expect(model.status == .failed(.microphoneDenied))
        #expect(capture.startCount == 0)
    }

    @Test("Restricted permission is reported distinctly")
    func restricted() async {
        let (model, _, _) = makeModel(authorization: .restricted)
        await model.start()
        #expect(model.failure == .microphoneRestricted)
    }

    @Test("First use asks for permission and starts when granted")
    func promptGranted() async {
        let (model, capture, _) = makeModel(authorization: .notDetermined, grantsRequests: true)
        await model.start()
        #expect(model.isListening)
        #expect(capture.startCount == 1)
        await model.stop()
    }

    @Test("Refusing the prompt fails")
    func promptRefused() async {
        let (model, capture, _) = makeModel(authorization: .notDetermined, grantsRequests: false)
        await model.start()
        #expect(model.failure == .microphoneDenied)
        #expect(capture.startCount == 0)
    }

    // MARK: Lifecycle

    @Test("Start and stop are idempotent and clear the output")
    func lifecycle() async {
        let (model, capture, _) = makeModel()
        await model.start()
        await model.start()
        #expect(capture.startCount == 1)
        #expect(model.isListening)

        _ = await feed(capture, model, midi: 45)
        #expect(model.reading != nil)

        await model.stop()
        #expect(model.status == .idle)
        #expect(model.reading == nil)
        #expect(model.inputLevel == 0)
        #expect(capture.stopCount >= 1)
        await model.stop() // harmless
    }

    @Test("Toggle flips between listening and idle")
    func toggle() async {
        let (model, _, _) = makeModel()
        await model.toggle()
        #expect(model.isListening)
        await model.toggle()
        #expect(model.status == .idle)
    }

    @Test("A backend that cannot start surfaces its failure")
    func startFailure() async {
        let capture = MockCapture()
        capture.failNextStart(with: .noInputAvailable)
        let (model, _, _) = makeModel(capture: capture)
        await model.start()
        #expect(model.failure == .noInputAvailable)

        // Recoverable: the next attempt works.
        capture.failNextStart(with: nil)
        await model.start()
        #expect(model.isListening)
        await model.stop()
    }

    // MARK: Output

    @Test("Detected notes reach the UI state")
    func detection() async throws {
        let (model, capture, _) = makeModel()
        await model.start()
        #expect(await feed(capture, model, midi: 50, cents: -12))
        let reading = try #require(model.reading)
        #expect(reading.stringIndex == 2)
        #expect(model.highlightedString == 2)
        #expect(abs(reading.cents + 12) < 2)
        #expect(model.hasSignal)
        #expect(model.inputLevel > 0)
        await model.stop()
    }

    @Test("Pinning a string measures against it and highlights it")
    func pinning() async throws {
        let (model, capture, _) = makeModel()
        model.pinString(0)
        #expect(model.target == .string(0))
        #expect(model.highlightedString == 0)
        await model.start()
        #expect(await feed(capture, model, midi: 40, cents: 9))
        #expect(abs(try #require(model.reading).cents - 9) < 2)
        model.releaseString()
        #expect(model.target == .automatic)
        await model.stop()
    }

    @Test("Pinning ignores invalid indices")
    func pinInvalid() {
        let (model, _, _) = makeModel()
        model.pinString(42)
        #expect(model.target == .automatic)
    }

    @Test("Changing tuning persists it and drops an invalid pin")
    func tuningChange() {
        let settings = makeSettings()
        let (model, _, _) = makeModel(settings: settings)
        model.pinString(5)
        model.tuning = .tuning(for: .dropC)
        #expect(settings.lastTuningID == .dropC)
        #expect(model.target == .string(5))
    }

    @Test("A4 from settings feeds the configuration")
    func calibration() {
        let settings = makeSettings()
        settings.referenceA = 432
        let (model, _, _) = makeModel(settings: settings)
        #expect(model.configuration.referenceA == 432)
    }

    // MARK: Failure & recovery

    @Test("Route changes restart capture automatically")
    func routeChange() async {
        let (model, capture, _) = makeModel()
        await model.start()
        capture.fail(with: .configurationChanged)
        #expect(await eventually { capture.startCount == 2 && model.isListening })
        await model.stop()
    }

    @Test("Interruptions are surfaced, not retried")
    func interruption() async {
        let (model, capture, _) = makeModel()
        await model.start()
        capture.fail(with: .interrupted)
        #expect(await eventually { model.failure == .interrupted })
        #expect(capture.startCount == 1)
    }

    @Test("Listening resumes by itself when an interruption ends")
    func interruptionEnds() async {
        let inputs = MutableInputs()
        let (model, capture, _) = makeModel(inputs: inputs)
        let monitor = Task { await model.monitorEnvironment() }
        await model.start()
        capture.fail(with: .interrupted)
        #expect(await eventually { model.failure == .interrupted })

        inputs.endInterruption()
        #expect(await eventually { model.isListening && capture.startCount == 2 })
        await model.stop()
        monitor.cancel()
    }

    @Test("The end of an interruption never starts a tuner that was not interrupted")
    func resumptionIgnoredWhenNotInterrupted() async {
        let inputs = MutableInputs()
        let (model, capture, _) = makeModel(authorization: .denied, inputs: inputs)
        let monitor = Task { await model.monitorEnvironment() }
        inputs.endInterruption()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.status == .idle)

        await model.start()
        inputs.endInterruption()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.failure == .microphoneDenied)
        #expect(capture.startCount == 0)
        monitor.cancel()
    }

    @Test("The permission explanation is only needed before the first prompt")
    func permissionExplanation() {
        #expect(makeModel(authorization: .notDetermined).0.needsMicrophonePermission)
        #expect(!makeModel(authorization: .authorized).0.needsMicrophonePermission)
        #expect(!makeModel(authorization: .denied).0.needsMicrophonePermission)
    }

    @Test("Unknown errors become engine failures")
    func unknownError() {
        struct Boom: Error {}
        if case .engineFailed = CaptureFailure(Boom()) {} else { Issue.record("expected engineFailed") }
        #expect(CaptureFailure(CaptureFailure.interrupted) == .interrupted)
    }

    // MARK: Power

    @Test("Listening stops after the configured silence")
    func idleTimeout() async {
        let settings = makeSettings()
        settings.idleTimeout = .oneMinute
        let clock = TestClock()
        let (model, capture, _) = makeModel(clock: clock, settings: settings)
        await model.start()

        // Quiet audio opens no gate → counts as silence. Let the session start counting first.
        for chunk in SignalGenerator.silence(count: 12_000).chunked(1_024) { capture.send(chunk) }
        try? await Task.sleep(for: .milliseconds(150))
        clock.advance(by: .seconds(61))
        for chunk in SignalGenerator.silence(count: 12_000).chunked(1_024) { capture.send(chunk) }

        #expect(await eventually { model.status == .idle })
        #expect(model.didStopForInactivity)
    }

    @Test("Playing keeps the session alive past the timeout")
    func activityResetsIdleTimer() async {
        let settings = makeSettings()
        settings.idleTimeout = .oneMinute
        let clock = TestClock()
        let (model, capture, _) = makeModel(clock: clock, settings: settings)
        await model.start()
        _ = await feed(capture, model, midi: 45)
        clock.advance(by: .seconds(50))
        _ = await feed(capture, model, midi: 45)
        clock.advance(by: .seconds(50))
        _ = await feed(capture, model, midi: 45)
        #expect(model.isListening)
        await model.stop()
    }

    @Test("Meter maps dBFS onto 0…1 monotonically")
    func meter() {
        #expect(TunerModel.meterLevel(rms: 0) == 0)
        #expect(TunerModel.meterLevel(rms: 1) == 1)
        let levels = [0.0005, 0.002, 0.01, 0.05, 0.2].map { TunerModel.meterLevel(rms: $0) }
        #expect(levels == levels.sorted())
        #expect(Set(levels).count == levels.count)
    }

    @Test("Low Power Mode slows the analysis rate")
    func powerProfile() {
        #expect(PowerProfile.efficient.engineParameters.hopDuration > PowerProfile.standard.engineParameters.hopDuration)
    }

    // MARK: Inputs

    @Test("Selecting an input persists it and restarts a running session")
    func selectInput() async {
        let devices = [AudioInputDevice(id: "usb", name: "USB Interface")]
        let settings = makeSettings()
        let (model, capture, _) = makeModel(inputs: StaticAudioInputs(devices: devices), settings: settings)
        await model.start()
        await model.selectInput(.device(id: "usb"))
        #expect(settings.lastInputID == "usb")
        #expect(model.activeInputName == "USB Interface")
        #expect(capture.startCount == 2)
        #expect(capture.lastInput == .device(id: "usb"))
        await model.stop()
    }

    @Test("Unplugging the selected input falls back to the system default")
    func hotUnplug() async {
        let usb = AudioInputDevice(id: "usb", name: "USB Interface")
        let inputs = MutableInputs([usb])
        let settings = makeSettings()
        settings.lastInputID = "usb"
        let (model, _, _) = makeModel(inputs: inputs, settings: settings)
        #expect(model.inputSelection == .device(id: "usb"))

        let monitor = Task { await model.monitorEnvironment() }
        #expect(await eventually { model.availableInputs == [usb] })

        inputs.set([])
        #expect(await eventually { model.inputSelection == .systemDefault })
        #expect(settings.lastInputID == nil)
        monitor.cancel()
    }

    @Test("A saved input that no longer exists is dropped at launch")
    func staleSavedInput() async {
        let settings = makeSettings()
        settings.lastInputID = "gone"
        let (model, _, _) = makeModel(settings: settings)
        let monitor = Task { await model.monitorEnvironment() }
        #expect(await eventually { model.inputSelection == .systemDefault })
        monitor.cancel()
    }
}

extension Array where Element == Float {
    func chunked(_ size: Int) -> [[Float]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

enum SignalGenerator {
    static func silence(count: Int) -> [Float] { [Float](repeating: 0, count: count) }
}
