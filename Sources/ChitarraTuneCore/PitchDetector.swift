import Foundation

public struct PitchResult: Sendable {
    public let frequency: Double
    public let clarity: Double
}

public struct PitchDetector: Sendable {
    public let sampleRate: Double
    public var minFrequency: Double = 70.0   // Hz (below low E to be safe)
    public var maxFrequency: Double = 600.0  // Hz (above high E to be safe)

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    // Estimate fundamental frequency using a simple autocorrelation with parabolic peak interpolation
    public func estimateFrequency(samples input: [Float]) -> PitchResult? {
        let n = input.count
        guard n >= 1024 else { return nil }

        // Copy and preprocess: remove DC, apply Hann window
        var samples = input
        let mean = samples.reduce(0, +) / Float(n)
        if mean != 0 {
            for i in 0..<n { samples[i] -= mean }
        }
        // Hann window
        for i in 0..<n {
            let w = 0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(n - 1)))
            samples[i] = Float(Double(samples[i]) * w)
        }

        // Autocorrelation for lags in plausible range
        let minLag = max(1, Int(sampleRate / maxFrequency))
        let maxLag = min(n - 1, Int(sampleRate / minFrequency))
        guard maxLag > minLag + 2 else { return nil }

        // Compute R[0] for normalization
        var r0: Double = 0
        for i in 0..<n {
            let s = Double(samples[i])
            r0 += s * s
        }
        guard r0 > 1e-12 else { return nil }

        var bestLag: Int = minLag
        var bestValue: Double = -Double.infinity
        var acf = [Double](repeating: 0, count: maxLag - minLag + 1)

        for lag in minLag...maxLag {
            var sum: Double = 0
            // dot product of x[0..N-lag-1] with x[lag..N-1]
            let upper = n - lag
            var i = 0
            while i < upper {
                sum += Double(samples[i]) * Double(samples[i + lag])
                i += 1
            }
            let norm = sum / r0
            let idx = lag - minLag
            acf[idx] = norm
            if norm > bestValue {
                bestValue = norm
                bestLag = lag
            }
        }

        // Reject weak peaks
        let clarity = max(0.0, min(1.0, bestValue))
        if clarity < 0.2 { // too noisy/unstable
            return nil
        }

        // Parabolic interpolation around best lag
        let peakIndex = bestLag - minLag
        var refinedLag = Double(bestLag)
        if peakIndex > 0 && peakIndex < acf.count - 1 {
            let alpha = acf[peakIndex - 1]
            let beta = acf[peakIndex]
            let gamma = acf[peakIndex + 1]
            let denom = (alpha - 2.0 * beta + gamma)
            if abs(denom) > 1e-12 {
                let p = 0.5 * (alpha - gamma) / denom
                refinedLag = Double(minLag + peakIndex) + p
            }
        }

        guard refinedLag > 0 else { return nil }
        let frequency = sampleRate / refinedLag
        guard frequency.isFinite, frequency > 10, frequency < 2000 else { return nil }
        return PitchResult(frequency: frequency, clarity: clarity)
    }
}

// Helper: full tuning estimate for guitar
public func estimateGuitarTuning(
    samples: [Float],
    sampleRate: Double,
    referenceA: Double = 440.0,
    forcedString: GuitarString? = nil
) -> TuningEstimate? {
    let detector = PitchDetector(sampleRate: sampleRate)
    guard let res = detector.estimateFrequency(samples: samples) else { return nil }
    if let forced = forcedString {
        let cents = 1200.0 * log2(res.frequency / scaledFrequency(for: forced, referenceA: referenceA))
        return TuningEstimate(frequency: res.frequency, clarity: res.clarity, nearestString: forced, cents: cents)
    } else {
        let nearest = nearestGuitarString(for: res.frequency, referenceA: referenceA)
        return TuningEstimate(frequency: res.frequency, clarity: res.clarity, nearestString: nearest.string, cents: nearest.cents)
    }
}
