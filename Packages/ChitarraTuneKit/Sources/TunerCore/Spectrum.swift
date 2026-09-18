import Foundation

/// Small spectral measurements.
enum Spectrum {
    /// Amplitude of the sinusoid at exactly `frequency` in `samples` (one Hann-windowed DFT bin,
    /// computed with the Goertzel recurrence), together with the RMS of `samples`. A pure sine of
    /// amplitude *a* at `frequency` gives `amplitude ≈ a`.
    ///
    /// - Returns: `nil` when there are fewer than two samples or the rate is not positive.
    static func tone(at frequency: Double, in samples: [Float], sampleRate: Double) -> (amplitude: Double, rms: Double)? {
        let count = samples.count
        guard count > 1, sampleRate > 0 else { return nil }
        let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
        var previous = 0.0, beforePrevious = 0.0, windowSum = 0.0, sumSquares = 0.0
        for index in 0..<count {
            let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(count - 1))
            let sample = Double(samples[index])
            let current = sample * window + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
            windowSum += window
            sumSquares += sample * sample
        }
        let power = max(0, previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious)
        return (2 * power.squareRoot() / windowSum, (sumSquares / Double(count)).squareRoot())
    }
}
