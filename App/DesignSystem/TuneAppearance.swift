import SwiftUI
import TunerCore

/// How close the current reading is to pitch. Never conveyed by colour alone: every state also has
/// a text label and a symbol.
enum TuneState: Equatable {
    case idle
    case flat(closeness: Closeness)
    case sharp(closeness: Closeness)
    case inTune

    enum Closeness { case close, far }

    init(_ reading: TunerReading?) {
        guard let reading else { self = .idle; return }
        if reading.isInTune { self = .inTune; return }
        let closeness: Closeness = abs(reading.cents) <= 15 ? .close : .far
        self = reading.cents < 0 ? .flat(closeness: closeness) : .sharp(closeness: closeness)
    }

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
    static let tuneGreen = Color(.tuneGreen)
    static let tuneAmber = Color(.tuneAmber)
    static let tuneRed = Color(.tuneRed)
}
