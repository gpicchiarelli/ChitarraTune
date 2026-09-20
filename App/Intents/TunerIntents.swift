import AppIntents
import TunerAudio
import TunerCore
import TunerFeature

// MARK: - Errors

enum TunerIntentError: Error, CustomLocalizedStringResourceConvertible {
    case stringOutOfRange
    case inputMissing

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .stringOutOfRange: .intentErrorStringRange
        case .inputMissing: .intentErrorInputMissing
        }
    }
}

// MARK: - Stop

// `StartTuningIntent` lives in Shared/, compiled into the app and the Controls extension.

struct StopTuningIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.stop.title")
    static let description = IntentDescription(LocalizedStringResource("intent.stop.description"))

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult {
        await hub.activeModel.stop()
        return .result()
    }
}

// MARK: - Tuning

struct SetTuningIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.tuning.title")
    static let description = IntentDescription(LocalizedStringResource("intent.tuning.description"))

    @Parameter(title: LocalizedStringResource("intent.tuning.parameter"))
    var tuning: TuningOption

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        hub.activeModel.tuning = .tuning(for: tuning.tuningID)
        return .result(dialog: IntentDialog(.intentTuningDialog(String(localized: tuning.tuningID.title))))
    }
}

// MARK: - Reference pitch

struct SetReferencePitchIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.pitch.title")
    static let description = IntentDescription(LocalizedStringResource("intent.pitch.description"))

    @Parameter(title: LocalizedStringResource("intent.pitch.parameter"), default: 440, inclusiveRange: (415, 466))
    var frequency: Int

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        hub.settings.referenceA = Double(frequency)
        return .result(dialog: IntentDialog(.intentPitchDialog(Int(hub.settings.referenceA))))
    }
}

// MARK: - String

struct PickStringIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.string.title")
    static let description = IntentDescription(LocalizedStringResource("intent.string.description"))

    @Parameter(title: LocalizedStringResource("intent.string.parameter"))
    var string: Int?

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = hub.activeModel
        guard let string else {
            model.releaseString()
            return .result(dialog: IntentDialog(.intentStringDialogAuto))
        }
        guard (1...model.tuning.stringCount).contains(string) else { throw TunerIntentError.stringOutOfRange }
        model.pinString(string - 1)
        return .result(dialog: IntentDialog(.intentStringDialogPinned(string)))
    }
}

// MARK: - Input device

struct AudioInputEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("intent.input.type"))
    static let defaultQuery = AudioInputQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// Lists the inputs the tuner itself sees (the hub's input provider), so Shortcuts and the app never
/// disagree, and demo mode never reaches real hardware.
struct AudioInputQuery: EntityQuery {
    @Dependency private var hub: TunerHub

    func entities(for identifiers: [String]) async throws -> [AudioInputEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AudioInputEntity] {
        let model = hub.activeModel
        model.refreshInputs()
        return model.availableInputs.map { AudioInputEntity(id: $0.id, name: $0.name) }
    }
}

struct ChooseInputIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.input.title")
    static let description = IntentDescription(LocalizedStringResource("intent.input.description"))

    @Parameter(title: LocalizedStringResource("intent.input.parameter"))
    var input: AudioInputEntity

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = hub.activeModel
        model.refreshInputs()
        guard model.availableInputs.contains(where: { $0.id == input.id }) else {
            throw TunerIntentError.inputMissing
        }
        await model.selectInput(.device(id: input.id))
        return .result(dialog: IntentDialog(.intentInputDialog(input.name)))
    }
}

// MARK: - Shortcuts

struct ChitarraTuneShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTuningIntent(),
            phrases: [
                "Start tuning in \(.applicationName)",
                "Start tuner in \(.applicationName)",
                "Tune my guitar with \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("shortcut.start.short"),
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopTuningIntent(),
            phrases: [
                "Stop tuning in \(.applicationName)",
                "Stop tuner in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("shortcut.stop.short"),
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: SetTuningIntent(),
            phrases: ["Set tuning in \(.applicationName)"],
            shortTitle: LocalizedStringResource("shortcut.tuning.short"),
            systemImageName: "guitars"
        )
    }
}
