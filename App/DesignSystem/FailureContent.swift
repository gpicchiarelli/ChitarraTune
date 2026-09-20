import SwiftUI
import TunerAudio

extension CaptureFailure {
    var title: LocalizedStringResource {
        switch self {
        case .microphoneDenied: .failureDeniedTitle
        case .microphoneRestricted: .failureRestrictedTitle
        case .noInputAvailable: .failureNoInputTitle
        case .inputUnavailable: .failureInputUnavailableTitle
        case .engineFailed, .configurationChanged: .failureEngineTitle
        case .interrupted: .failureInterruptedTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .microphoneDenied: .failureDeniedMessage
        case .microphoneRestricted: .failureRestrictedMessage
        case .noInputAvailable: .failureNoInputMessage
        case .inputUnavailable: .failureInputUnavailableMessage
        case .engineFailed, .configurationChanged: .failureEngineMessage
        case .interrupted: .failureInterruptedMessage
        }
    }

    var symbol: String {
        switch self {
        case .microphoneDenied, .microphoneRestricted: "mic.slash.fill"
        case .noInputAvailable, .inputUnavailable: "cable.connector.slash"
        case .engineFailed, .configurationChanged: "exclamationmark.triangle.fill"
        case .interrupted: "phone.down.fill"
        }
    }

    /// `true` when only the user can fix it in system settings.
    var needsSystemSettings: Bool {
        self == .microphoneDenied
    }
}
