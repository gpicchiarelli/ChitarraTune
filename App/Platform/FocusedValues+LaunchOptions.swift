import SwiftUI
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
}
