import SwiftUI
import TunerFeature

/// Presentation of ``TuneState``. Never conveyed by colour alone: every state also has a text label
/// and a distinct symbol (Differentiate Without Color).
extension TuneState {
    var tint: Color {
        switch self {
        case .idle: .secondary
        case .inTune: .tuneGreen
        case .flat(.close), .sharp(.close): .tuneAmber
        case .flat(.far), .sharp(.far): .tuneRed
        }
    }

    var symbol: String {
        switch self {
        case .idle: "waveform"
        case .inTune: "checkmark.circle.fill"
        case .flat: "arrow.up.circle.fill"
        case .sharp: "arrow.down.circle.fill"
        }
    }

    var title: LocalizedStringResource? {
        switch self {
        case .idle: nil
        case .inTune: .tunerStatusInTune
        case .flat: .tunerStatusFlat
        case .sharp: .tunerStatusSharp
        }
    }

    var advice: LocalizedStringResource? {
        switch self {
        case .flat: .tunerAdviceTighten
        case .sharp: .tunerAdviceLoosen
        default: nil
        }
    }
}

extension Color {
    /// Foreground colours: text and symbols on the window background (≥ 4.5:1 in every appearance).
    static let tuneGreen = Color(.tuneGreen)
    static let tuneAmber = Color(.tuneAmber)
    static let tuneRed = Color(.tuneRed)

    /// Fills behind white text and symbols (buttons, selected chips). Unlike the foreground colours
    /// they stay dark in Dark Mode, so white on them keeps ≥ 5.8:1 (the accent fill ≥ 8:1).
    static let tuneAccentFill = Color(.tuneAccentFill)
    static let tuneGreenFill = Color(.tuneGreenFill)
    static let tuneRedFill = Color(.tuneRedFill)

    /// Secondary text. The system's secondary label is about 3.4:1 on white; this one keeps
    /// ≥ 5.5:1 on every background the app draws (≥ 9:1 with Increase Contrast).
    static let tuneSecondaryLabel = Color(.tuneSecondaryLabel)
    /// Accent-coloured text, and the pale opaque accent it sits on (secondary buttons).
    static let tuneAccentText = Color(.tuneAccentText)
    static let tuneAccentTint = Color(.tuneAccentTint)
}
