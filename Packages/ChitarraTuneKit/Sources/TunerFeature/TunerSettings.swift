import Foundation
import Observation
import TunerCore

/// User preferences shared by every tuner window. Persisted in `UserDefaults`.
///
/// The keys `A4`, `tuningPresetID` and `preferredInputUID` are the ones used by earlier releases,
/// so existing users keep their calibration and tuning after updating.
@MainActor
@Observable
public final class TunerSettings {
    public enum NotationPreference: String, CaseIterable, Sendable {
        case automatic, english, solfege
    }

    public enum GaugeStyle: String, CaseIterable, Sendable {
        case dial, bar
    }

    /// Stop listening after this much silence (saves battery when the app is left open).
    public enum IdleTimeout: Int, CaseIterable, Sendable {
        case never = 0
        case oneMinute = 60
        case threeMinutes = 180
        case fiveMinutes = 300

        public var seconds: Double? { self == .never ? nil : Double(rawValue) }
    }

    private enum Key {
        static let referenceA = "A4"
        static let tuning = "tuningPresetID"
        static let input = "preferredInputUID"
        static let notation = "settings.notation"
        static let gauge = "settings.gauge"
        static let haptics = "settings.haptics"
        static let idle = "settings.idleTimeout"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Concert pitch (A4) in hertz, `415…466`.
    public var referenceA: Double {
        didSet {
            let valid = PitchMath.validReferenceA(referenceA)
            if valid != referenceA || referenceA.isNaN { referenceA = valid; return }
            defaults.set(referenceA, forKey: Key.referenceA)
        }
    }

    public var notation: NotationPreference {
        didSet { defaults.set(notation.rawValue, forKey: Key.notation) }
    }

    public var gaugeStyle: GaugeStyle {
        didSet { defaults.set(gaugeStyle.rawValue, forKey: Key.gauge) }
    }

    public var isHapticsEnabled: Bool {
        didSet { defaults.set(isHapticsEnabled, forKey: Key.haptics) }
    }

    public var idleTimeout: IdleTimeout {
        didSet { defaults.set(idleTimeout.rawValue, forKey: Key.idle) }
    }

    /// Defaults for newly opened tuner windows (last used).
    public var lastTuningID: TuningID {
        didSet { defaults.set(lastTuningID.rawValue, forKey: Key.tuning) }
    }

    public var lastInputID: String? {
        didSet { defaults.set(lastInputID ?? "", forKey: Key.input) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedA4 = defaults.object(forKey: Key.referenceA) as? Double ?? PitchMath.standardReferenceA
        referenceA = PitchMath.validReferenceA(storedA4)
        notation = defaults.string(forKey: Key.notation).flatMap(NotationPreference.init) ?? .automatic
        gaugeStyle = defaults.string(forKey: Key.gauge).flatMap(GaugeStyle.init) ?? .dial
        isHapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        idleTimeout = (defaults.object(forKey: Key.idle) as? Int).flatMap(IdleTimeout.init(rawValue:)) ?? .threeMinutes
        lastTuningID = defaults.string(forKey: Key.tuning).flatMap(TuningID.init) ?? .standard
        let storedInput = defaults.string(forKey: Key.input) ?? ""
        lastInputID = storedInput.isEmpty ? nil : storedInput
    }

    /// Resolves ``notation`` for a locale. "Automatic" uses solfège in the languages where fixed-do
    /// is the everyday convention (Italian, Spanish, French, Portuguese, Romanian, Catalan…).
    public func resolvedNotation(for locale: Locale = .current) -> NoteNotation {
        switch notation {
        case .english: .english
        case .solfege: .solfege
        case .automatic: NoteNotation.conventional(for: locale)
        }
    }
}

extension NoteNotation {
    /// Fixed-do languages.
    private static let solfegeLanguages: Set<String> = ["it", "es", "fr", "pt", "ro", "ca", "gl"]

    public static func conventional(for locale: Locale) -> NoteNotation {
        guard let code = locale.language.languageCode?.identifier else { return .english }
        return solfegeLanguages.contains(code) ? .solfege : .english
    }
}
