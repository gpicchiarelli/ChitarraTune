import Foundation

/// Deterministic synthetic audio used by the DSP tests.
enum SignalGenerator {
    /// A plucked-string-like tone: a sum of harmonics with the given relative amplitudes.
    static func tone(
        frequency: Double,
        sampleRate: Double = 44_100,
        duration: Double = 0.5,
        harmonics: [Double] = [1],
        amplitude: Double = 0.3,
        phase: Double = 0
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        let norm = harmonics.reduce(0) { $0 + abs($1) }
        return (0..<count).map { n in
            let t = Double(n) / sampleRate
            var value = 0.0
            for (index, weight) in harmonics.enumerated() {
                value += weight * sin(2 * .pi * frequency * Double(index + 1) * t + phase)
            }
            return Float(amplitude * value / norm)
        }
    }

    /// Guitar-like spectrum: strong fundamental with decaying overtones.
    static let guitarHarmonics: [Double] = [1, 0.6, 0.4, 0.25, 0.15, 0.1]

    /// Spectrum where the 2nd harmonic dominates (typical for low strings on small speakers).
    static let weakFundamental: [Double] = [0.35, 1, 0.5, 0.3]

    /// Deterministic pseudo-random noise (xorshift), uniform in `-amplitude...amplitude`.
    static func noise(count: Int, amplitude: Double, seed: UInt64 = 0x9E3779B97F4A7C15) -> [Float] {
        var state = seed
        return (0..<count).map { _ in
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            let unit = Double(state % 20_001) / 10_000 - 1
            return Float(unit * amplitude)
        }
    }

    static func silence(count: Int) -> [Float] { [Float](repeating: 0, count: count) }
}

extension Array where Element == Float {
    /// Splits into consecutive chunks of `size` samples, like a capture callback would.
    func chunked(_ size: Int) -> [[Float]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
