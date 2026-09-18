import Accelerate
import Foundation

/// A pitch hypothesis produced by ``PitchDetector``.
public struct PitchEstimate: Sendable, Hashable {
    /// Fundamental frequency in hertz.
    public let frequency: Double
    /// Periodicity confidence, `0...1` (1 − CMNDF minimum). Values below ~0.5 are unreliable.
    public let clarity: Double

    public init(frequency: Double, clarity: Double) {
        self.frequency = frequency
        self.clarity = clarity
    }
}

/// Monophonic fundamental-frequency estimator based on the YIN algorithm
/// (de Cheveigné & Kawahara, 2002): difference function → cumulative mean normalised
/// difference (CMNDF) → absolute threshold → parabolic interpolation. ``refine(_:lowPassed:)``
/// then removes the sharp bias that inharmonic strings give YIN.
///
/// Create one detector per (sample rate, frequency range) pair and feed it the most recent
/// ``requiredSampleCount`` samples. The correlation is evaluated in the frequency domain with
/// Accelerate, so one analysis costs a few tens of microseconds on Apple silicon.
///
/// The detector reuses internal scratch buffers and an FFT plan, so it is a reference type that
/// must stay confined to one isolation domain (an actor, a queue or the main actor); it is
/// intentionally not `Sendable`.
public final class PitchDetector {
    public let sampleRate: Double
    public let minFrequency: Double
    public let maxFrequency: Double

    /// CMNDF value below which a dip is accepted as the fundamental period.
    public let threshold: Double

    /// Length of the fixed integration window `W` (samples).
    public let integrationLength: Int
    /// Number of samples that must be supplied to ``estimate(in:)``.
    public let requiredSampleCount: Int

    private let minLag: Int
    private let maxLag: Int
    private let correlator: CrossCorrelator

    // Scratch memory reused by every analysis.
    private var work: [Float]
    private var prefix: [Double]
    private var correlation: [Double]
    private var difference: [Double]
    private var cmnd: [Double]

    /// - Returns: `nil` when the parameters cannot describe a valid analysis
    ///   (non-positive sample rate, empty or inverted range, range above Nyquist/4).
    public init?(
        sampleRate: Double,
        frequencyRange: ClosedRange<Double>,
        threshold: Double = 0.15
    ) {
        guard sampleRate.isFinite, sampleRate > 0, frequencyRange.lowerBound > 0,
              frequencyRange.upperBound < sampleRate / 4
        else { return nil }

        let maxLag = Int((sampleRate / frequencyRange.lowerBound).rounded(.up))
        let minLag = max(2, Int((sampleRate / frequencyRange.upperBound).rounded(.down)))
        guard maxLag > minLag + 2 else { return nil }

        self.sampleRate = sampleRate
        self.minFrequency = frequencyRange.lowerBound
        self.maxFrequency = frequencyRange.upperBound
        self.threshold = threshold
        self.minLag = minLag
        self.maxLag = maxLag
        // Two periods of the lowest frequency give a stable minimum; +1 lag for interpolation.
        // The floor keeps very high ranges (short periods) statistically stable.
        let window = max(640, 2 * maxLag)
        self.integrationLength = window
        self.requiredSampleCount = window + maxLag + 1
        guard let correlator = CrossCorrelator(minimumSize: requiredSampleCount) else { return nil }
        self.correlator = correlator
        work = [Float](repeating: 0, count: requiredSampleCount)
        prefix = [Double](repeating: 0, count: requiredSampleCount + 1)
        correlation = [Double](repeating: 0, count: maxLag + 2)
        difference = [Double](repeating: 0, count: maxLag + 2)
        cmnd = [Double](repeating: 1, count: maxLag + 2)
    }

    /// Estimates the fundamental frequency of the **last** ``requiredSampleCount`` samples.
    ///
    /// - Returns: `nil` if there are too few samples or no periodicity was found.
    public func estimate(in samples: [Float]) -> PitchEstimate? {
        guard samples.count >= requiredSampleCount else { return nil }
        let count = requiredSampleCount
        // Work on a demeaned copy: microphones and interfaces often carry a DC offset, which YIN
        // would read as a perfectly periodic (constant) signal.
        samples.withUnsafeBufferPointer { source in
            let tail = UnsafeBufferPointer(rebasing: source[(source.count - count)...])
            var mean: Float = 0
            vDSP_meanv(tail.baseAddress!, 1, &mean, vDSP_Length(count))
            var negated = -mean
            work.withUnsafeMutableBufferPointer { work in
                vDSP_vsadd(tail.baseAddress!, 1, &negated, work.baseAddress!, 1, vDSP_Length(count))
            }
        }
        return analyse()
    }

    // MARK: - Algorithm

    /// Runs YIN on `work` using only preallocated scratch memory (no per-call allocation).
    private func analyse() -> PitchEstimate? {
        guard computeCMNDF() else { return nil }

        // Step 4: first dip under the threshold, followed down to its local minimum.
        var lag = minLag
        var chosen: Int?
        while lag <= maxLag {
            if cmnd[lag] < threshold {
                while lag + 1 <= maxLag, cmnd[lag + 1] < cmnd[lag] { lag += 1 }
                chosen = lag
                break
            }
            lag += 1
        }
        // No dip under the threshold: fall back to the global minimum (low clarity, callers gate on it).
        if chosen == nil {
            chosen = (minLag...maxLag).min { cmnd[$0] < cmnd[$1] }
        }
        guard var best = chosen else { return nil }

        // Octave-error correction: a genuine period P also makes 2P, 3P… dip, so multiples are
        // only preferred when their dip is *clearly deeper* (weak-fundamental strings).
        let primary = best
        for multiple in 2...4 {
            let centre = primary * multiple
            guard centre + multiple <= maxLag else { break }
            let span = (centre - multiple)...(centre + multiple)
            if let deeper = span.min(by: { cmnd[$0] < cmnd[$1] }),
               cmnd[deeper] + Self.octaveMargin < cmnd[best] {
                best = deeper
            }
        }

        // Step 5: parabolic interpolation around the minimum.
        let refined = interpolatedLag(best)
        guard refined > 0 else { return nil }

        let periodic = sampleRate / refined
        guard periodic.isFinite, periodic >= minFrequency * 0.9, periodic <= maxFrequency * 1.1 else {
            return nil
        }
        let clarity = min(1, max(0, 1 - cmnd[best]))
        return PitchEstimate(frequency: periodic, clarity: clarity)
    }

    /// Fills `cmnd` for the samples in `work`. Returns `false` for a silent window.
    private func computeCMNDF() -> Bool {
        let window = integrationLength
        let lagCount = maxLag + 1 // lags 1…maxLag+1 (one extra for interpolation at the edge)

        // Prefix sums of x² give the energy of any shifted window in O(1).
        prefix[0] = 0
        for i in 0..<requiredSampleCount {
            let sample = Double(work[i])
            prefix[i + 1] = prefix[i] + sample * sample
        }
        let energy0 = prefix[window]
        // Below ≈ −100 dBFS RMS there is nothing but rounding noise (e.g. a pure DC input).
        guard energy0 / Double(window) > 1e-10 else { return false }

        // Step 1–2: difference function d(τ) = E₀ + E_τ − 2·c(τ)  (c = cross-correlation).
        work.withUnsafeBufferPointer { x in
            correlation.withUnsafeMutableBufferPointer { output in
                correlator.correlate(
                    UnsafeBufferPointer(rebasing: x[0..<window]),
                    x,
                    lagCount: lagCount + 1,
                    into: output
                )
            }
        }
        for lag in 1...lagCount {
            let shifted = prefix[lag + window] - prefix[lag]
            difference[lag] = max(0, energy0 + shifted - 2 * correlation[lag])
        }

        // Step 3: cumulative mean normalised difference.
        var running = 0.0
        for lag in 1...lagCount {
            running += difference[lag]
            cmnd[lag] = running > 0 ? difference[lag] * Double(lag) / running : 1
        }
        return true
    }

    /// Parabolic interpolation of the minimum of `curve` (the CMNDF or the raw difference) at `lag`.
    private func interpolatedLag(_ lag: Int, in curve: [Double]? = nil) -> Double {
        let curve = curve ?? cmnd
        var refined = Double(lag)
        if lag > 1, lag < maxLag + 1 {
            let left = curve[lag - 1], mid = curve[lag], right = curve[lag + 1]
            let denominator = left - 2 * mid + right
            if abs(denominator) > 1e-12 {
                refined += 0.5 * (left - right) / denominator
            }
        }
        return refined
    }

    // MARK: - Low-partial refinement

    /// Largest correction the refinement may apply, in cents. Inharmonicity moves the first pass
    /// by a few cents; anything larger means the refinement found something else.
    public static let maximumRefinement = 15.0
    /// Highest CMNDF value at which the band-limited period is trusted.
    public static let refinementClarity = 0.1

    /// Measures the period again on `lowPassed` — the same audio after a low-pass that keeps only
    /// the fundamental and part of the second partial (see ``PartialFilter``) — around `estimate`.
    ///
    /// Stiff strings are slightly inharmonic: overtone `k` sits about `866·B·k²` cents sharp of
    /// `k·f0`, so the full waveform is not quite periodic and the first pass is pulled sharp by the
    /// upper partials (one to four cents on a steel string). Without them the shift is a fraction
    /// of a cent. Returns `estimate` unchanged whenever the refinement is not trustworthy.
    public func refine(_ estimate: Double, lowPassed samples: [Float]) -> Double {
        guard samples.count >= requiredSampleCount, estimate.isFinite, estimate > 0 else { return estimate }
        let count = requiredSampleCount
        samples.withUnsafeBufferPointer { source in
            let tail = UnsafeBufferPointer(rebasing: source[(source.count - count)...])
            var mean: Float = 0
            vDSP_meanv(tail.baseAddress!, 1, &mean, vDSP_Length(count))
            var negated = -mean
            work.withUnsafeMutableBufferPointer { work in
                vDSP_vsadd(tail.baseAddress!, 1, &negated, work.baseAddress!, 1, vDSP_Length(count))
            }
        }
        guard computeCMNDF() else { return estimate }

        // The raw difference, not the CMNDF: on a smooth two-partial signal the dip is broad, and
        // the CMNDF's running-mean normalisation would tilt it and move its minimum.
        let lag = Int((sampleRate / estimate).rounded())
        let span = max(2, lag / 8)
        let lower = max(minLag, lag - span), upper = min(maxLag, lag + span)
        guard lower < upper,
              let best = (lower...upper).min(by: { difference[$0] < difference[$1] }),
              best != lower, best != upper,
              // Too noisy to be periodic (the band may hold little more than hum and rumble).
              cmnd[best] <= Self.refinementClarity
        else { return estimate }
        let frequency = sampleRate / interpolatedLag(best, in: difference)
        let correction = abs(1200 * log2(frequency / estimate))
        return frequency.isFinite && correction <= Self.maximumRefinement ? frequency : estimate
    }

    /// How much deeper (in CMNDF units) a multiple-lag dip must be to replace the primary one.
    static let octaveMargin = 0.06
}
