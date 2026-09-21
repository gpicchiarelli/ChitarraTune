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
    /// No tuner window could be put on screen, so nothing was started (ADR 0012 rule 4).
    enum Failure: Error, CustomLocalizedStringResourceConvertible {
        case noTunerWindow

        var localizedStringResource: LocalizedStringResource { LocalizedStringResource("intent.error.unavailable") }
    }

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
        //
        // And when none appears, say so: a dialog reading “Listening. Play a string.” over a tuner
        // that never started is worse than an error, because nothing else will correct it.
        guard await hub.startOnVisibleTuner() else { throw Failure.noTunerWindow }
        return .result(dialog: IntentDialog(LocalizedStringResource("intent.start.dialog")))
    }
}
