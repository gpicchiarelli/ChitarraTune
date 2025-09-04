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

    // Estimate fundamental frequency using YIN (CMNDF) with parabolic refinement
    public func estimateFrequency(samples input: [Float]) -> PitchResult? {
        let n = input.count
        guard n >= 1024 else { return nil }

        // Preprocess: remove DC, apply Hann window
        var x = input
        var mean: Float = 0
        for i in 0..<n { mean += x[i] }
        mean /= Float(n)
        if mean != 0 { for i in 0..<n { x[i] -= mean } }
        for i in 0..<n {
            let w = 0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(n - 1)))
            x[i] = Float(Double(x[i]) * w)
        }

        let minLag = max(2, Int(sampleRate / maxFrequency))
        let maxLag = min(n / 2, Int(sampleRate / minFrequency))
        guard maxLag > minLag + 2 else { return nil }

        // Difference function d(tau)
        var d = [Float](repeating: 0, count: maxLag + 1)
        for tau in 1...maxLag {
            var sum: Float = 0
            let upper = n - tau
            var i = 0
            while i < upper {
                let diff = x[i] - x[i + tau]
                sum += diff * diff
                i += 1
            }
            d[tau] = sum
        }

        // Cumulative mean normalized difference function (CMNDF)
        var cmnd = [Float](repeating: 1, count: maxLag + 1)
        var runningSum: Float = 0
        for tau in 1...maxLag {
            runningSum += d[tau]
            if runningSum != 0 {
                cmnd[tau] = d[tau] * Float(tau) / runningSum
            } else {
                cmnd[tau] = 1
            }
        }

        // Absolute threshold search
        let threshold: Float = 0.12
        var tauEstimate = -1
        var tau = minLag
        while tau <= maxLag {
            if cmnd[tau] < threshold {
                // Local minimum search
                while tau + 1 <= maxLag && cmnd[tau + 1] < cmnd[tau] { tau += 1 }
                tauEstimate = tau
                break
            }
            tau += 1
        }
        if tauEstimate == -1 {
            // Fallback to global minimum in range
            var minVal: Float = 1
            var minIdx: Int = minLag
            for i in minLag...maxLag {
                if cmnd[i] < minVal { minVal = cmnd[i]; minIdx = i }
            }
            tauEstimate = minIdx
        }

        // Parabolic interpolation around minimum
        var refinedLag = Float(tauEstimate)
        if tauEstimate > 1 && tauEstimate < maxLag {
            let s0 = cmnd[tauEstimate - 1]
            let s1 = cmnd[tauEstimate]
            let s2 = cmnd[tauEstimate + 1]
            let denom = (2 * s1 - s0 - s2)
            if abs(denom) > 1e-12 {
                let delta = 0.5 * (s0 - s2) / denom
                refinedLag += delta
            }
        }

        guard refinedLag > 0 else { return nil }
        let frequency = sampleRate / Double(refinedLag)
        guard frequency.isFinite, frequency > 10, frequency < 2000 else { return nil }

        // Clarity: invert CMNDF minimum (0 -> poor, 1 -> perfect)
        var minCmnd = cmnd[tauEstimate]
        if tauEstimate > 1 && tauEstimate < maxLag {
            minCmnd = min(minCmnd, cmnd[tauEstimate - 1])
            minCmnd = min(minCmnd, cmnd[tauEstimate + 1])
        }
        let clarity = max(0, min(1, 1 - Double(minCmnd)))
        if clarity < 0.15 { return nil }
        return PitchResult(frequency: frequency, clarity: clarity)
    }
}

// Helper: full tuning estimate for guitar
public func estimatePresetTuning(
    samples: [Float],
    sampleRate: Double,
    referenceA: Double = 440.0,
    preset: TuningPreset,
    forcedIndex: Int? = nil
) -> TuningEstimate? {
    let detector = PitchDetector(sampleRate: sampleRate)
    guard let res = detector.estimateFrequency(samples: samples) else { return nil }
    if let idx = forcedIndex, idx >= 0, idx < preset.strings.count {
        // Normalize by octaves near target to mitigate octave errors under strong plucks
        let targetF = frequency(for: preset.strings[idx].midi, referenceA: referenceA)
        var f = res.frequency
        var ratio = f / targetF
        while ratio > 1.9 { f /= 2; ratio /= 2 }
        while ratio < 0.55 { f *= 2; ratio *= 2 }
        let cents = 1200.0 * log2(f / targetF)
        return TuningEstimate(
            frequency: f,
            clarity: res.clarity,
            stringLabel: preset.strings[idx].label,
            cents: cents,
            stringIndex: idx
        )
    } else {
        let nearest = nearestString(in: preset, for: res.frequency, referenceA: referenceA)
        return TuningEstimate(
            frequency: res.frequency,
            clarity: res.clarity,
            stringLabel: nearest.label,
            cents: nearest.cents,
            stringIndex: nearest.index
        )
    }
}

// Backward-compatible helper that assumes Standard tuning
public func estimateGuitarTuning(
    samples: [Float],
    sampleRate: Double,
    referenceA: Double = 440.0,
    forcedString: GuitarString? = nil
) -> TuningEstimate? {
    // Map legacy enum to standard preset indices
    let standard = DefaultTuningPresets.first { $0.id == "standard" }!
    var forcedIndex: Int? = nil
    if let forced = forcedString {
        let mapping: [GuitarString: Int] = [.e2: 0, .a2: 1, .d3: 2, .g3: 3, .b3: 4, .e4: 5]
        forcedIndex = mapping[forced]
    }
    return estimatePresetTuning(samples: samples, sampleRate: sampleRate, referenceA: referenceA, preset: standard, forcedIndex: forcedIndex)
}
