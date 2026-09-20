import Foundation
import Testing
import TunerAudio
import TunerCore
@testable import TunerFeature

@MainActor
@Suite("Documented behaviour · TunerFeature")
struct SpecConformanceFeatureTests {
    @Test("Analysis cadence: 25 ms normally, 45 ms in Low Power Mode or under thermal pressure")
    func cadence() {
        #expect(PowerProfile.standard.engineParameters.hopDuration == 0.025)
        #expect(PowerProfile.efficient.engineParameters.hopDuration == 0.045)
    }

    @Test("Idle timeout offers never, one, three and five minutes; three is the default")
    func idleTimeouts() {
        #expect(TunerSettings.IdleTimeout.allCases.map(\.rawValue) == [0, 60, 180, 300])
        #expect(TunerSettings.IdleTimeout.never.seconds == nil)
        #expect(TunerSettings.IdleTimeout.fiveMinutes.seconds == 300)
        #expect(makeSettings().idleTimeout == .threeMinutes)
    }

    @Test("Automatic notation is solfège in exactly the fixed-do languages", arguments: [
        ("it", NoteNotation.solfege), ("es", .solfege), ("fr", .solfege), ("pt", .solfege),
        ("ro", .solfege), ("ca", .solfege), ("gl", .solfege),
        ("en", .english), ("de", .english), ("ja", .english), ("nl", .english), ("sv", .english),
    ])
    func fixedDoLanguages(language: String, expected: NoteNotation) {
        #expect(NoteNotation.conventional(for: Locale(identifier: language)) == expected)
    }

    @Test("Settings that the README lists default as documented")
    func documentedDefaults() {
        let settings = makeSettings()
        #expect(settings.gaugeStyle == .dial)
        #expect(settings.isHapticsEnabled)
        #expect(settings.notation == .automatic)
        #expect(settings.referenceA == 440)
        #expect(TunerSettings.GaugeStyle.allCases.count == 2)
        #expect(TunerSettings.NotationPreference.allCases.count == 3)
    }

    @Test("A route that keeps changing gives up after three automatic restarts")
    func restartBudget() async {
        let capture = MockCapture()
        let model = TunerModel(
            settings: makeSettings(),
            capture: capture,
            authorization: FixedMicrophoneAuthorization(),
            inputs: MutableInputs()
        )
        await model.start()
        for expectedStarts in 2...4 {
            capture.fail(with: .configurationChanged)
            #expect(await eventually { capture.startCount == expectedStarts && model.isListening })
        }
        capture.fail(with: .configurationChanged)
        #expect(await eventually { model.failure == .configurationChanged })
        #expect(capture.startCount == 4)
    }

    @Test("Stopping releases the capture exactly once and leaves the model idle")
    func stopReleasesCapture() async {
        let capture = MockCapture()
        let model = TunerModel(
            settings: makeSettings(),
            capture: capture,
            authorization: FixedMicrophoneAuthorization(),
            inputs: MutableInputs()
        )
        await model.start()
        await model.stop()
        #expect(model.status == .idle)
        #expect(capture.stopCount >= 1)
        #expect(model.reading == nil && !model.hasSignal && model.inputLevel == 0)
    }
}
