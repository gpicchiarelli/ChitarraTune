import Foundation

/// Streaming band-pass tuned to one string: a 4th-order Butterworth low-pass that passes the
/// fundamental, keeps part of the second partial and removes the upper partials whose
/// inharmonicity would bias the period (see ``PitchDetector/refine(_:lowPassed:)``), a 2nd-order
/// high-pass below the fundamental that removes room rumble, and notches at the mains frequencies
/// inside the band (see ``humNotches(for:)``).
///
/// It runs on the continuous audio stream rather than on each analysis window, so its state carries
/// over from one chunk to the next and there are no edge transients to distort the period. A
/// causal IIR filter delays a steady tone but does not change its period.
///
/// The sections run in double precision, one sample after the other. The poles of a low-pass at a
/// hundred hertz sit within 2 % of the unit circle, where single precision (`vDSP_biquad`) loses
/// digits, and a vectorised kernel rounds differently depending on where the stream was cut into
/// chunks. Here the output depends only on the samples: not on the chunking, not on the CPU.
///
/// A value type: its state (two numbers per section) carries over from one chunk to the next, and a
/// copy is an independent filter, so copying a ``TuningEngine`` copies its filters too.
public struct PartialFilter: Sendable {
    /// Cutoff relative to the string's frequency. Across the engine's ±300 cent capture window the
    /// third partial loses at least 15 dB (22 dB on pitch). Within ±50 cents of pitch the fundamental
    /// loses at most 5 dB, most of it to the hum notches; further out it may sit near a notch and
    /// lose more, which only makes the refinement decline. No linear filter changes the period of a
    /// steady tone, which is what is measured.
    public static let cutoffRatio = 1.6
    /// High-pass corner relative to the string's frequency: rumble at a fifth of it loses 16 dB.
    public static let highPassRatio = 0.5

    /// One second-order section, transposed direct form II, normalised so that `a0 == 1`.
    struct Section: Sendable {
        var b0, b1, b2, a1, a2: Double
        var z1 = 0.0, z2 = 0.0

        init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
            (self.b0, self.b1, self.b2, self.a1, self.a2) = (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
        }

        /// Decay time constant of the section's slowest pole, in samples. The poles are the roots of
        /// z² + a1·z + a2: a conjugate pair of modulus √a2, or two real roots (Q ≤ 0.5).
        var timeConstant: Double {
            Self.timeConstant(a1: a1, a2: a2)
        }

        static func timeConstant(a1: Double, a2: Double) -> Double {
            let discriminant = a1 * a1 - 4 * a2
            let root = abs(discriminant).squareRoot()
            let radius = discriminant < 0 ? a2.squareRoot() : (abs(a1) + root) / 2
            return radius > 0 && radius < 1 ? -1 / log(radius) : 0
        }

        mutating func callAsFunction(_ x: Double) -> Double {
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            return y
        }
    }

    public let cutoff: Double
    private var sections: [Section]

    /// - Returns: `nil` if the cutoff is not below the Nyquist frequency.
    public init?(frequency: Double, sampleRate: Double) {
        let cutoff = Self.cutoffRatio * frequency
        guard cutoff.isFinite, sampleRate.isFinite, cutoff > 0, cutoff < sampleRate * 0.45 else { return nil }
        let omega = 2 * .pi * cutoff / sampleRate
        let cosine = cos(omega), sine = sin(omega)
        // Two low-pass sections with the Q values of a 4th-order Butterworth.
        sections = [0.541_196_100_146_197, 1.306_562_964_876_376].map { q in
            let alpha = sine / (2 * q)
            return Section(b0: (1 - cosine) / 2, b1: 1 - cosine, b2: (1 - cosine) / 2,
                           a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha)
        }
        let highOmega = 2 * .pi * Self.highPassRatio * frequency / sampleRate
        let highCosine = cos(highOmega), highAlpha = sin(highOmega) / (2 * 0.707_106_781_186_548)
        sections.append(Section(b0: (1 + highCosine) / 2, b1: -(1 + highCosine), b2: (1 + highCosine) / 2,
                                a0: 1 + highAlpha, a1: -2 * highCosine, a2: 1 - highAlpha))
        for hum in Self.humNotches(for: frequency) {
            let humOmega = 2 * .pi * hum / sampleRate
            let humCosine = cos(humOmega), humAlpha = sin(humOmega) / (2 * Self.humNotchQ)
            sections.append(Section(b0: 1, b1: -2 * humCosine, b2: 1,
                                    a0: 1 + humAlpha, a1: -2 * humCosine, a2: 1 - humAlpha))
        }
        self.cutoff = cutoff
        settlingSamples = Int(sections.reduce(0) { max($0, $1.timeConstant) } * Self.settlingTimeConstants) + 1
    }

    /// How many time constants of its slowest section the filter needs after an attack before its
    /// output is the steady response to the string (e^−5 < 1 % of the transient left).
    public static let settlingTimeConstants = 5.0
    /// Samples the filter needs, after an attack, before it measures the string rather than its own
    /// ringing (see ``settlingTimeConstants``).
    public let settlingSamples: Int

    // MARK: - Mains hum

    /// Mains frequencies and the harmonics that reach the lowest strings' bands: 50 Hz (Europe, most
    /// of Asia and Africa) and 60 Hz (the Americas, parts of Asia) families.
    public static let mainsHum: [Double] = [50, 60, 100, 120, 150, 180, 200, 240, 250, 300]
    /// Quality factor of each hum notch: 12 Hz wide at 50 Hz, wide enough for the grid's drift, and
    /// short-ringing (a 25 ms time constant at 50 Hz). Narrower notches ring longer after every
    /// attack; wider ones take more of a nearby fundamental.
    public static let humNotchQ = 4.0
    /// A notch is never placed this close to the string's target (in cents): the fundamental of a
    /// string being tuned is there, and a notch would take it.
    public static let humNotchClearance = 300.0

    /// Hum inside the band beats with the fundamental and makes the refined period oscillate at the
    /// beat frequency (±3 cents on a low D against 50 Hz). Averaging over time only cancels that if the
    /// analyses happen to fall on different phases of the beat; at a beat of one cycle per analysis
    /// the error is sampled at the same phase every time and becomes a bias; and hum below the
    /// fundamental also pulls the average flat. So the hum is removed from the band instead: a notch
    /// at every mains frequency inside it, except close to the fundamental.
    static func humNotches(for frequency: Double) -> [Double] {
        let band = (highPassRatio * frequency * 0.9)...(cutoffRatio * frequency * 1.1)
        let clearance = pow(2, humNotchClearance / 1_200)
        return mainsHum.filter { band.contains($0) && ($0 < frequency / clearance || $0 > frequency * clearance) }
    }

    /// Filters the next chunk of the stream.
    public mutating func process(_ samples: [Float]) -> [Float] {
        sections.withUnsafeMutableBufferPointer { sections in
            samples.map { sample in
                var value = Double(sample)
                for index in sections.indices { value = sections[index](value) }
                return Float(value)
            }
        }
    }

    /// Forgets the filter state (after a gap in the stream).
    public mutating func reset() {
        for index in sections.indices { (sections[index].z1, sections[index].z2) = (0, 0) }
    }
}
