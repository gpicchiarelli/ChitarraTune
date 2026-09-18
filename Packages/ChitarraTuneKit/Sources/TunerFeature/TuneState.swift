import TunerCore

/// How close the current reading is to pitch. UI layers map it to colour, symbol and text; it is
/// deliberately coarse so observers only wake up when the *category* changes, not on every frame.
public enum TuneState: Sendable, Hashable {
    case idle
    case flat(Closeness)
    case sharp(Closeness)
    case inTune

    public enum Closeness: Sendable, Hashable { case close, far }

    /// Deviation (cents) up to which a not-yet-in-tune string still counts as "close".
    public static let closeThreshold = 15.0

    public init(_ reading: TunerReading?) {
        guard let reading else { self = .idle; return }
        if reading.isInTune { self = .inTune; return }
        let closeness: Closeness = abs(reading.cents) <= Self.closeThreshold ? .close : .far
        self = reading.cents < 0 ? .flat(closeness) : .sharp(closeness)
    }
}
