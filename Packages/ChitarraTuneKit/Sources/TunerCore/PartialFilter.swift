import Accelerate
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
/// Holds an Accelerate biquad setup, so it is a reference type confined to one isolation domain.
public final class PartialFilter {
    /// Cutoff relative to the string's frequency. With the ±300 cent capture window of the engine
    /// the fundamental always stays in the passband and the third partial is at least 20 dB down.
    public static let cutoffRatio = 1.6
    /// High-pass corner relative to the string's frequency.
    public static let highPassRatio = 0.5

    public let cutoff: Double
    private let setup: vDSP_biquad_Setup
    private var delay: [Float]
    private var output: [Float] = []

    /// - Returns: `nil` if the cutoff is not below the Nyquist frequency.
    public init?(frequency: Double, sampleRate: Double) {
        let cutoff = Self.cutoffRatio * frequency
        guard cutoff.isFinite, sampleRate.isFinite, cutoff > 0, cutoff < sampleRate * 0.45 else { return nil }
        let omega = 2 * .pi * cutoff / sampleRate
        let cosine = cos(omega), sine = sin(omega)
        var coefficients: [Double] = []
        // Two sections with the Q values of a 4th-order Butterworth.
        for q in [0.541_196_100_146_197, 1.306_562_964_876_376] {
            let alpha = sine / (2 * q)
            let a0 = 1 + alpha
            coefficients += [(1 - cosine) / 2 / a0, (1 - cosine) / a0, (1 - cosine) / 2 / a0,
                             -2 * cosine / a0, (1 - alpha) / a0]
        }
        let highOmega = 2 * .pi * Self.highPassRatio * frequency / sampleRate
        let highCosine = cos(highOmega), highAlpha = sin(highOmega) / (2 * 0.707_106_781_186_548)
        let h0 = 1 + highAlpha
        coefficients += [(1 + highCosine) / 2 / h0, -(1 + highCosine) / h0, (1 + highCosine) / 2 / h0,
                         -2 * highCosine / h0, (1 - highAlpha) / h0]
        guard let setup = vDSP_biquad_CreateSetup(coefficients, 3) else { return nil }
        self.cutoff = cutoff
        self.setup = setup
        delay = [Float](repeating: 0, count: 2 * 3 + 2)
    }

    deinit { vDSP_biquad_DestroySetup(setup) }

    /// Filters the next chunk of the stream.
    public func process(_ samples: [Float]) -> [Float] {
        if output.count != samples.count { output = [Float](repeating: 0, count: samples.count) }
        vDSP_biquad(setup, &delay, samples, 1, &output, 1, vDSP_Length(samples.count))
        return output
    }

    /// Forgets the filter state (after a gap in the stream).
    public func reset() {
        for index in delay.indices { delay[index] = 0 }
    }
}
