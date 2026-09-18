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
        return UserDefaults(suiteName: suite)!
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
        #expect(hub.model(for: id) === hub.model(for: id))
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

    @Test("Demo hub never needs the microphone")
    func demoHub() async {
        let hub = TunerHub.demo()
        let model = hub.primary
        await model.start()
        #expect(model.isListening)
        #expect(await eventually { model.reading != nil })
        await hub.stopAll()
        #expect(model.status == .idle)
    }
}
