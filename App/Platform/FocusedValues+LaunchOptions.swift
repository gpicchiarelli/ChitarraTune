import SwiftUI
import TunerAudio
import TunerFeature

extension FocusedValues {
    /// The tuner of the focused window; menu commands act on it.
    @Entry var tuner: TunerModel?
}

/// Launch arguments used by demo mode, screenshots and UI tests.
///
/// Debug builds only (ADR 0006): a shipping build ignores every one of them, so nothing outside the
/// app can switch it to a synthetic microphone or fake a permission. UI tests and screenshots run the
/// Debug configuration.
enum LaunchOptions {
    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments
    #else
    private static let arguments: [String] = []
    #endif

    /// Synthetic guitar instead of the microphone; no permission prompt.
    static let isDemo = arguments.contains("-demo")
    /// Begin listening as soon as the window appears.
    static let autostart = arguments.contains("-autostart")
    /// Demo mode only: the microphone permission to pretend (`-demoPermission notDetermined|denied`),
    /// so UI tests can reach the explanation screen and the failure screen.
    static var demoPermission: MicrophoneAuthorization {
        guard isDemo else { return .authorized }
        return switch UserDefaults.standard.string(forKey: "demoPermission") {
        case "notDetermined": .notDetermined
        case "denied": .denied
        default: .authorized
        }
    }
    /// Demo mode only: force an appearance (`-demoAppearance dark|light`) for screenshots, where
    /// switching the simulator's appearance while the app runs is not reliable.
    static var demoColorScheme: ColorScheme? {
        guard isDemo else { return nil }
        switch UserDefaults.standard.string(forKey: "demoAppearance") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}
