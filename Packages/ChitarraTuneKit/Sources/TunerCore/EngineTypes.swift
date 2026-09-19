import Foundation

// MARK: - Configuration

/// Which string the user wants to tune.
public enum StringTarget: Sendable, Hashable {
    /// Detect the string automatically from the played pitch.
    case automatic
    /// Compare against one specific string (index into ``Tuning/strings``).
    case string(Int)
}

/// Everything the engine needs to interpret a pitch. Cheap to copy and compare.
public struct TunerConfiguration: Sendable, Hashable {
    public var tuning: Tuning
    public var referenceA: Double
    public var target: StringTarget

    public init(
        tuning: Tuning = .standard,
        referenceA: Double = PitchMath.standardReferenceA,
        target: StringTarget = .automatic
    ) {
        self.tuning = tuning
        self.referenceA = PitchMath.validReferenceA(referenceA)
        self.target = target
    }
}

/// Tunable thresholds of the analysis pipeline. All durations are in seconds so that behaviour
/// does not depend on the device sample rate.
public struct EngineParameters: Sendable, Hashable {
    /// Time between two analyses.
    public var hopDuration: Double = 0.025
    /// Window the signal level (and therefore the noise gate and the attack test) is measured over.
    /// In seconds, so that behaviour does not depend on the device's sample rate.
    public var levelWindowDuration: Double = 2_048 / 44_100
    /// RMS above which the noise gate opens.
    public var gateOpenLevel: Double = 0.004
    /// RMS below which an open gate closes (hysteresis avoids chatter).
    public var gateCloseLevel: Double = 0.0025
    /// Minimum ``PitchEstimate/clarity`` accepted.
    public var minimumClarity: Double = 0.55
    /// Deviations beyond this many cents from the target string are ignored.
    public var maximumDeviation: Double = 300
    /// A jump larger than this many cents restarts smoothing instead of averaging.
    public var smoothingResetJump: Double = 60
    /// Smoothing factor range (higher clarity → less smoothing), as the weight of a new measurement
    /// per ``smoothingReference`` seconds. The engine converts it to its actual analysis interval, so
    /// the needle settles in the same time whatever the analysis rate.
    public var smoothingFactor: ClosedRange<Double> = 0.25...0.7
    /// Deviation (cents) inside which a string counts as in tune.
    public var inTuneThreshold: Double = 5
    /// Extra tolerance before an in-tune string is considered out of tune again.
    public var inTuneExitMargin: Double = 2
    /// Consecutive in-tune analyses required to declare "in tune".
    public var stableHopsRequired: Int = 6
    /// How long the last reading stays visible after the signal fades.
    public var holdDuration: Double = 0.8
    /// A level rise by this factor counts as a new pluck (which may be a different string).
    public var attackRatio: Double = 1.5
    /// Within this many cents of an exact octave of the note being followed, a detection without a
    /// new pluck is treated as an octave error and folded back.
    public var octaveContinuityWindow: Double = 35
    /// Folding a detection *down* onto the followed note needs that note's fundamental to still be
    /// there: at least this fraction of the signal's RMS at exactly that frequency (−20 dB).
    /// Otherwise a new, higher string was played (E2 → E4, D2 → D3 → D4) and is reported as such.
    public var fundamentalPresenceRatio: Double = 0.1
    /// Weight of a new measurement in the running inharmonicity correction, per ``smoothingReference``
    /// seconds (converted to the actual analysis interval like ``smoothingFactor``).
    public var correctionSmoothing: Double = 0.15

    /// Time step the smoothing weights are defined for: the standard analysis interval.
    public static let smoothingReference = 0.025

    public static let standard = EngineParameters()

    public init() {}
}

// MARK: - Output

/// A single interpreted pitch reading.
public struct TunerReading: Sendable, Hashable {
    /// Detected frequency after octave correction (Hz).
    public var frequency: Double
    /// Frequency the string should have (Hz).
    public var targetFrequency: Double
    /// Index of the target string inside the tuning.
    public var stringIndex: Int
    /// Note of the target string.
    public var note: Note
    /// Smoothed deviation from the target in cents (positive = sharp).
    public var cents: Double
    /// Detector confidence, `0...1`.
    public var clarity: Double
    /// `true` once the deviation stayed inside the in-tune window long enough.
    public var isInTune: Bool
    /// `true` while an old reading is kept on screen after the signal has faded.
    public var isHeld: Bool
}

/// Result of one analysis step.
public struct TunerFrame: Sendable, Hashable {
    /// RMS level of the analysed window, `0...1`.
    public var level: Double
    /// Whether the noise gate is open (something audible is being played).
    public var isSignalPresent: Bool
    /// Current reading, `nil` when nothing (or nothing valid) is being played.
    public var reading: TunerReading?
}
