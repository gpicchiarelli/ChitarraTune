import Foundation

public enum GuitarString: CaseIterable, Sendable {
    case e2, a2, d3, g3, b3, e4

    public var name: String {
        switch self {
        case .e2: return "E2"
        case .a2: return "A2"
        case .d3: return "D3"
        case .g3: return "G3"
        case .b3: return "B3"
        case .e4: return "E4"
        }
    }

    /// Base frequency with A4 = 440 Hz
    public var baseFrequency: Double {
        switch self {
        case .e2: return 82.4069
        case .a2: return 110.0
        case .d3: return 146.832
        case .g3: return 196.0
        case .b3: return 246.942
        case .e4: return 329.628
        }
    }
}

public struct TuningEstimate: Sendable {
    public let frequency: Double
    public let clarity: Double
    public let nearestString: GuitarString
    public let cents: Double

    public init(frequency: Double, clarity: Double, nearestString: GuitarString, cents: Double) {
        self.frequency = frequency
        self.clarity = clarity
        self.nearestString = nearestString
        self.cents = cents
    }
}

@inlinable
public func scaledFrequency(for string: GuitarString, referenceA: Double = 440.0) -> Double {
    let scale = referenceA / 440.0
    return string.baseFrequency * scale
}

@inlinable
public func nearestGuitarString(for frequency: Double, referenceA: Double = 440.0) -> (string: GuitarString, cents: Double) {
    let best = GuitarString.allCases.min { a, b in
        abs(log2(frequency / scaledFrequency(for: a, referenceA: referenceA)))
        < abs(log2(frequency / scaledFrequency(for: b, referenceA: referenceA)))
    } ?? .e2
    let cents = 1200.0 * log2(frequency / scaledFrequency(for: best, referenceA: referenceA))
    return (best, cents)
}
