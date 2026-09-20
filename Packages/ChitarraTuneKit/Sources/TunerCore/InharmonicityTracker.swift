import Foundation

/// The inharmonicity correction of the string being followed, in cents.
///
/// It is a property of the string, stable over a pluck, while each single measurement of it is
/// noisy, so it is averaged over time. It is also an offset of the instrument, not an observation:
/// ``applied`` records the correction included in the last reading, so that the engine can move its
/// averaged history when the correction changes (see ``TuningEngine``).
struct InharmonicityTracker {
    /// The string the correction belongs to, if any.
    private(set) var string: Int?
    /// The running correction for ``string``.
    private(set) var cents = 0.0
    /// The correction included in the last reading.
    var applied = 0.0

    /// The correction already known for `string`, without a new measurement.
    func known(for string: Int) -> Double? {
        self.string == string ? cents : nil
    }

    /// Adds one refined measurement for `string` (`nil` when this analysis could not refine the
    /// period) and returns the running correction. `weight` is the share of a new measurement.
    mutating func update(measured: Double?, estimate: Double, string: Int, weight: Double) -> Double {
        guard self.string == string else {
            self.string = string
            cents = measured.map { PitchMath.cents(from: $0, to: estimate) } ?? 0
            return cents
        }
        if let measured {
            cents += weight * (PitchMath.cents(from: measured, to: estimate) - cents)
        }
        return cents
    }
}
