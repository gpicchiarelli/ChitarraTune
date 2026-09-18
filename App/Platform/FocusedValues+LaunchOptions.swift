import SwiftUI
import TunerAudio
import TunerFeature

extension FocusedValues {
    /// The tuner of the focused window; menu commands act on it.
    @Entry var tuner: TunerModel?
}

/// Launch arguments used by demo mode, screenshots and UI tests.
enum LaunchOptions {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// Synthetic guitar instead of the microphone; no permission prompt.
    static let isDemo = arguments.contains("-demo")
    /// Begin listening as soon as the window appears.
    static let autostart = arguments.contains("-autostart")
    /// Demo mode only: the microphone permission to pretend (`-demoPermission notDetermined|denied`),
    /// so UI tests can reach the explanation screen and the failure screen.
    static var demoPermission: MicrophoneAuthorization {
        switch UserDefaults.standard.string(forKey: "demoPermission") {
        case "notDetermined": .notDetermined
        case "denied": .denied
        default: .authorized
        }
    }
}
