import Foundation
import Observation
import TunerAudio

/// Owns every tuner window's ``TunerModel`` and remembers which one was used last, so
/// system-wide entry points (App Intents, Siri, Action Button) know which tuner to drive.
@MainActor
@Observable
public final class TunerHub {
    public let settings: TunerSettings
    /// Identifier of the model used by the first window (and by scenes that have no explicit id).
    nonisolated public let primaryID = UUID()

    public private(set) var activeID: UUID?

    @ObservationIgnored private var models: [UUID: TunerModel] = [:]
    @ObservationIgnored private let makeModel: @MainActor (UUID, TunerSettings) -> TunerModel

    public init(
        settings: TunerSettings,
        makeModel: @escaping @MainActor (UUID, TunerSettings) -> TunerModel
    ) {
        self.settings = settings
        self.makeModel = makeModel
    }

    /// The model for a window, created on first use (also after state restoration).
    public func model(for id: UUID) -> TunerModel {
        if let model = models[id] { return model }
        let model = makeModel(id, settings)
        models[id] = model
        return model
    }

    public var primary: TunerModel { model(for: primaryID) }

    /// The tuner that was focused last.
    public var activeModel: TunerModel {
        activeID.flatMap { models[$0] } ?? primary
    }

    public func activate(_ id: UUID) {
        if activeID != id { activeID = id }
    }

    /// Releases a closed window's model and stops its audio. The primary model is kept.
    public func discard(_ id: UUID) async {
        guard id != primaryID, let model = models.removeValue(forKey: id) else { return }
        await model.stop()
        if activeID == id { activeID = nil }
    }

    public func stopAll() async {
        for model in models.values { await model.stop() }
    }

    // MARK: - Factories

    /// Real microphone.
    public static func live(settings: TunerSettings = TunerSettings()) -> TunerHub {
        let inputs = SystemAudioInputs()
        let authorization = SystemMicrophoneAuthorization()
        return TunerHub(settings: settings) { id, settings in
            TunerModel(
                id: id,
                settings: settings,
                capture: EngineAudioCapture(),
                authorization: authorization,
                inputs: inputs
            )
        }
    }

    /// Synthetic guitar, no microphone, no permission prompt: for screenshots, previews and UI tests.
    /// `permission` lets a UI test start from a microphone permission that has not been asked yet.
    public static func demo(
        settings: TunerSettings = TunerSettings(defaults: demoDefaults()),
        permission: MicrophoneAuthorization = .authorized
    ) -> TunerHub {
        let inputs = StaticAudioInputs(
            devices: [
                AudioInputDevice(id: "demo.interface", name: "USB Audio Interface"),
                AudioInputDevice(id: "demo.builtin", name: "Built-in Microphone"),
            ],
            defaultName: "Built-in Microphone"
        )
        return TunerHub(settings: settings) { id, settings in
            TunerModel(
                id: id,
                settings: settings,
                capture: SimulatedAudioCapture(referenceA: { @MainActor in settings.referenceA }),
                authorization: FixedMicrophoneAuthorization(permission),
                inputs: inputs
            )
        }
    }

    /// Throw-away defaults so demo mode never touches the user's real preferences.
    ///
    /// If the suite cannot be opened (a reserved name) it falls back to a private suite, never to
    /// `.standard`: that would write demo values into the real preferences and then wipe them.
    public static func demoDefaults(suite: String = "com.chitarratune.demo") -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suite) else {
            return demoDefaults(suite: "com.chitarratune.demo.isolated")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
