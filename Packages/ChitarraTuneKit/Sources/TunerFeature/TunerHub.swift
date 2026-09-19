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
    /// Windows showing a tuner right now, in the order they appeared.
    public private(set) var visibleIDs: [UUID] = []

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

    /// The tuner that system-wide entry points (Siri, Shortcuts, the Dock menu, Control Center) act
    /// on: the window focused last while it is still open, otherwise the newest open window, otherwise
    /// the primary tuner (which then needs a window: see ``hasVisibleTuner``).
    public var activeModel: TunerModel {
        if let id = activeID, visibleIDs.contains(id) { return model(for: id) }
        return visibleIDs.last.map(model(for:)) ?? primary
    }

    /// `false` when no window shows a tuner: an entry point that starts listening must open one
    /// first, or the microphone would run with nothing on screen.
    public var hasVisibleTuner: Bool { !visibleIDs.isEmpty }

    /// A window started showing the tuner `id`.
    public func windowAppeared(_ id: UUID) {
        if !visibleIDs.contains(id) { visibleIDs.append(id) }
    }

    /// The window of `id` became the focused one.
    public func activate(_ id: UUID) {
        windowAppeared(id)
        if activeID != id { activeID = id }
    }

    /// A window was closed: its tuner stops listening and stops being the active one. Every model
    /// except the primary one is released.
    public func discard(_ id: UUID) async {
        visibleIDs.removeAll { $0 == id }
        if activeID == id { activeID = visibleIDs.last }
        guard let model = models[id] else { return }
        if id != primaryID { models[id] = nil }
        await model.stop()
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
