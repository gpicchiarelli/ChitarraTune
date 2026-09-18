import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Small bridges to platform-only APIs.
enum PlatformSettings {
    /// Opens the microphone privacy pane (macOS) or the app's Settings page (iOS).
    static func openMicrophonePrivacy() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// Keeps the screen on while listening (iOS); the display sleeps as usual once listening stops.
    static func setKeepScreenAwake(_ awake: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = awake
        #endif
    }
}
