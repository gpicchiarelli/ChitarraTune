import Foundation
import Testing
import TunerCore
import TunerAudio
@testable import TunerFeature

@MainActor
@Suite("TunerSettings")
struct TunerSettingsTests {
    private func defaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.\(name).\(UUID().uuidString)"
        return UserDefaults(suiteName: suite) ?? { preconditionFailure("cannot open test defaults \(suite)") }()
    }

    @Test("Fresh install defaults")
    func defaultsOnFreshInstall() {
        let settings = TunerSettings(defaults: defaults())
        #expect(settings.referenceA == 440)
        #expect(settings.lastTuningID == .standard)
        #expect(settings.lastInputID == nil)
        #expect(settings.notation == .automatic)
        #expect(settings.gaugeStyle == .dial)
        #expect(settings.isHapticsEnabled)
        #expect(settings.idleTimeout == .threeMinutes)
    }

    @Test("Values round-trip through UserDefaults")
    func persistence() {
        let store = defaults()
        let first = TunerSettings(defaults: store)
        first.referenceA = 432
        first.notation = .solfege
        first.gaugeStyle = .bar
        first.isHapticsEnabled = false
        first.idleTimeout = .never
        first.lastTuningID = .dadgad
        first.lastInputID = "usb"

        let second = TunerSettings(defaults: store)
        #expect(second.referenceA == 432)
        #expect(second.notation == .solfege)
        #expect(second.gaugeStyle == .bar)
        #expect(!second.isHapticsEnabled)
        #expect(second.idleTimeout == .never)
        #expect(second.lastTuningID == .dadgad)
        #expect(second.lastInputID == "usb")
    }

    @Test("Preferences written by earlier releases are honoured")
    func legacyKeys() {
        let store = defaults()
        store.set(442.0, forKey: "A4")
        store.set("dropD", forKey: "tuningPresetID")
        store.set("BuiltInMicrophoneDevice", forKey: "preferredInputUID")
        let settings = TunerSettings(defaults: store)
        #expect(settings.referenceA == 442)
        #expect(settings.lastTuningID == .dropD)
        #expect(settings.lastInputID == "BuiltInMicrophoneDevice")
    }

    @Test("Corrupt stored values fall back safely")
    func corruptValues() {
        let store = defaults()
        store.set(9_999.0, forKey: "A4")
        store.set("nonsense", forKey: "tuningPresetID")
        store.set("nonsense", forKey: "settings.notation")
        store.set(7, forKey: "settings.idleTimeout")
        let settings = TunerSettings(defaults: store)
        #expect(settings.referenceA == 466)
        #expect(settings.lastTuningID == .standard)
        #expect(settings.notation == .automatic)
        #expect(settings.idleTimeout == .threeMinutes)
    }

    @Test("A4 is clamped when set")
    func clamping() {
        let settings = TunerSettings(defaults: defaults())
        settings.referenceA = 100
        #expect(settings.referenceA == 415)
        settings.referenceA = 900
        #expect(settings.referenceA == 466)
    }

    @Test("A NaN A4 falls back to 440 instead of poisoning the engine")
    func nanReferencePitch() {
        let store = defaults()
        store.set(Double.nan, forKey: "A4")
        let settings = TunerSettings(defaults: store)
        #expect(settings.referenceA == 440)

        settings.referenceA = 432
        settings.referenceA = .nan
        #expect(settings.referenceA == 440)
        #expect(TunerConfiguration(referenceA: settings.referenceA).referenceA == 440)
    }

    @Test("Automatic notation follows the language", arguments: [
        ("it_IT", NoteNotation.solfege), ("es_ES", .solfege), ("fr_FR", .solfege), ("pt_BR", .solfege),
        ("en_US", .english), ("de_DE", .english), ("ja_JP", .english),
    ])
    func automaticNotation(identifier: String, expected: NoteNotation) {
        let settings = TunerSettings(defaults: defaults())
        #expect(settings.resolvedNotation(for: Locale(identifier: identifier)) == expected)
    }

    @Test("Explicit notation ignores the language")
    func explicitNotation() {
        let settings = TunerSettings(defaults: defaults())
        settings.notation = .english
        #expect(settings.resolvedNotation(for: Locale(identifier: "it_IT")) == .english)
        settings.notation = .solfege
        #expect(settings.resolvedNotation(for: Locale(identifier: "en_US")) == .solfege)
    }
}

@MainActor
@Suite("TunerHub")
struct TunerHubTests {
    private func makeHub() -> TunerHub {
        let settings = makeSettings()
        return TunerHub(settings: settings) { id, settings in
            TunerModel(id: id, settings: settings, capture: MockCapture(),
                       authorization: FixedMicrophoneAuthorization(), inputs: StaticAudioInputs())
        }
    }

    @Test("Models are created lazily and reused")
    func reuse() {
        let hub = makeHub()
        let id = UUID()
        let first = hub.model(for: id)
        #expect(hub.model(for: id) === first)
        #expect(hub.model(for: id).id == id)
        #expect(hub.primary === hub.model(for: hub.primaryID))
    }

    @Test("The active model defaults to the primary and follows activation")
    func activation() {
        let hub = makeHub()
        #expect(hub.activeModel === hub.primary)
        let other = hub.model(for: UUID())
        hub.activate(other.id)
        #expect(hub.activeModel === other)
    }

    @Test("Discarding stops audio and forgets non-primary models only")
    func discard() async {
        let hub = makeHub()
        let extra = hub.model(for: UUID())
        await extra.start()
        hub.activate(extra.id)
        await hub.discard(extra.id)
        #expect(extra.status == .idle)
        #expect(hub.activeModel === hub.primary)
        #expect(hub.model(for: extra.id) !== extra)

        await hub.discard(hub.primaryID)
        #expect(hub.primary.id == hub.primaryID)
    }

    @Test("The active tuner follows focus, and only among open windows")
    func focusFollowsWindows() {
        let hub = makeHub()
        let second = hub.model(for: UUID())
        hub.windowAppeared(hub.primaryID)
        hub.windowAppeared(second.id)
        hub.windowAppeared(second.id)
        #expect(hub.visibleIDs == [hub.primaryID, second.id])
        #expect(hub.activeModel === second, "with nothing focused yet, the newest window")
        hub.activate(hub.primaryID)
        #expect(hub.activeModel === hub.primary)
        hub.activate(second.id)
        #expect(hub.activeModel === second)
    }

    /// Regression: closing the focused primary window left it active, and *Start* from the Dock or
    /// Siri then turned the microphone on for a tuner that had no window.
    @Test("Closing the focused window hands over to an open one; with none open, a window is needed")
    func closingTheFocusedWindow() async {
        let hub = makeHub()
        let second = hub.model(for: UUID())
        hub.windowAppeared(second.id)
        hub.activate(hub.primaryID)
        await hub.primary.start()
        await hub.discard(hub.primaryID)
        #expect(hub.primary.status == .idle, "a closed window's tuner stops listening")
        #expect(hub.activeModel === second)
        #expect(hub.hasVisibleTuner)

        await hub.discard(second.id)
        #expect(!hub.hasVisibleTuner)
        #expect(hub.activeModel === hub.primary, "the primary tuner, which the caller must show first")
        #expect(hub.activeID == nil)
    }

    @Test("Waiting for a tuner window is event-driven and bounded")
    func waitForWindow() async {
        let hub = makeHub()
        async let appeared = hub.waitForVisibleTuner(timeout: .seconds(30))
        await Task.yield()
        hub.windowAppeared(hub.primaryID)
        #expect(await appeared, "resumed by the window, long before the timeout")
        #expect(await hub.waitForVisibleTuner(timeout: .zero), "already visible")

        let empty = makeHub()
        #expect(await empty.waitForVisibleTuner(timeout: .milliseconds(10)) == false)
    }

    @Test("Demo hub never needs the microphone")
    func demoHub() async {
        let hub = TunerHub.demo()
        let model = hub.primary
        await model.start()
        #expect(model.isListening)
        // The demo guitar plays in real time: while the DSP suites saturate every core in the same
        // test run, its first reading can take far longer than on an idle machine (0.05 s). The
        // timeout only bounds a failure; a passing run returns as soon as the reading arrives.
        #expect(await eventually(timeout: .seconds(60)) { model.reading != nil })
        await hub.stopAll()
        #expect(model.status == .idle)
    }
}
