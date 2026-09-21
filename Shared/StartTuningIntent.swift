import AppIntents
import TunerFeature

/// Starts listening. Shared by the app (Siri, Shortcuts, the Action Button) and the Controls
/// extension (Control Center, the Lock Screen, the Mac menu bar): the extension only describes the
/// control, and because the microphone needs the foreground, the system always runs the intent in
/// the app.
///
/// Compiled into both targets, so it uses literal string keys (present in both string catalogs)
/// rather than the app's generated string symbols.
struct StartTuningIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("intent.start.title")
    static let description = IntentDescription(LocalizedStringResource("intent.start.description"))
    /// The microphone can only be used by a foreground app: the intent always brings the app forward
    /// before it runs.
    static let supportedModes: IntentModes = .foreground

    @Dependency private var hub: TunerHub

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Not `hub.activeModel.start()`: ADR 0012 rule 4. Brought forward by `supportedModes`, the
        // app may still have no tuner window — launched in the background, or the scene not yet
        // created — and the microphone must not run for a tuner nobody can see. The hub opens one
        // and waits for it; the Dock menu takes the same path.
        await hub.startOnVisibleTuner()
        return .result(dialog: IntentDialog(LocalizedStringResource("intent.start.dialog")))
    }
}
