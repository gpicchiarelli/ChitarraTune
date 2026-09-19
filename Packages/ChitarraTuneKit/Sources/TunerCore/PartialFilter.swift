import Foundation

/// Streaming band-pass tuned to one string: a 4th-order Butterworth low-pass that passes the
/// fundamental, keeps part of the second partial and removes the upper partials whose
/// inharmonicity would bias the period (see ``PitchDetector/refine(_:lowPassed:)``), and a
/// 2nd-order high-pass below the fundamental that removes mains hum and room rumble.
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
    /// fundamental loses less than 1 dB and the third partial at least 15 dB (22 dB on pitch).
    public static let cutoffRatio = 1.6
    /// High-pass corner relative to the string's frequency: rumble at a fifth of it loses 16 dB.
    public static let highPassRatio = 0.5

    /// One second-order section, transposed direct form II, normalised so that `a0 == 1`.
    private struct Section: Sendable {
        var b0, b1, b2, a1, a2: Double
        var z1 = 0.0, z2 = 0.0

        init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
            (self.b0, self.b1, self.b2, self.a1, self.a2) = (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
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
        self.cutoff = cutoff
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
