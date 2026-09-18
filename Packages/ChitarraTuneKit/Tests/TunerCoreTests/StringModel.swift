import Foundation

/// A physically informed model of a plucked steel string heard through a real microphone.
///
/// ``SignalGenerator`` produces clean harmonic tones, which are good for checking the maths but kind
/// to the detector. This model adds what makes guitars hard to tune in practice:
///
/// - **Inharmonicity**: stiff strings have sharp overtones, `f_k = k·f0·√(1 + B·k²)`.
/// - **Pluck position**: plucking near the bridge sets the partial amplitudes (`|sin(π·k·p)| / k`),
///   and removes partials with a node at the pluck point.
/// - **Partial decay**: upper partials die away faster than the fundamental.
/// - **Microphone response**: a phone microphone rolls off the low end, so on the low strings the
///   fundamental can be several times weaker than the second harmonic.
/// - **Attack**: a short noise burst from the pick.
/// - **Room**: broadband noise and mains hum.
///
/// It is still a model, not a recording. Real recordings go in `Fixtures/Recordings`
/// (see ``RecordingCorpusTests``).
struct StringModel {
    enum Microphone {
        /// Flat response (an audio interface with a pickup or a good microphone).
        case flat
        /// Second-order high-pass at `cutoff` Hz, like the small microphone of a phone.
        case phone(cutoff: Double)

        func gain(at frequency: Double) -> Double {
            switch self {
            case .flat: return 1
            case .phone(let cutoff):
                let ratio = (frequency / cutoff) * (frequency / cutoff)
                return ratio / (1 + ratio)
            }
        }
    }

    var inharmonicity = 1.2e-4
    var pluckPosition = 0.18
    var partials = 14
    /// Decay time of the fundamental in seconds.
    var decay = 2.5
    var microphone = Microphone.flat
    var attackNoise = 0.15
    /// Background noise RMS relative to full scale.
    var roomNoise = 0.002
    /// Mains hum amplitude (50 Hz).
    var hum = 0.003
    var amplitude = 0.3
    var seed: UInt64 = 0x2545F4914F6CDD1D

    /// Frequency of partial `k` (1-based) for a string whose fundamental is `f0`.
    func partialFrequency(_ k: Int, f0: Double) -> Double {
        Double(k) * f0 * (1 + inharmonicity * Double(k * k)).squareRoot()
    }

    func pluck(frequency f0: Double, sampleRate: Double, duration: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var random = Random(seed: seed)
        let nyquist = sampleRate / 2

        struct Partial { var frequency, weight, decay, phase: Double }
        var components: [Partial] = []
        for k in 1...partials {
            let frequency = partialFrequency(k, f0: f0)
            guard frequency < nyquist * 0.9 else { break }
            let shape = abs(sin(.pi * Double(k) * pluckPosition)) / Double(k)
            let weight = shape * microphone.gain(at: frequency)
            components.append(Partial(
                frequency: frequency,
                weight: weight,
                decay: decay / (1 + 0.08 * pow(Double(k), 1.5)),
                phase: random.unit() * 2 * .pi
            ))
        }
        let norm = components.reduce(0) { $0 + $1.weight }
        guard norm > 0 else { return [Float](repeating: 0, count: count) }

        // Each partial is a damped rotating phasor: one complex multiply per sample instead of a
        // sine and an exponential (the tests synthesise thousands of plucks).
        var real = components.map { $0.weight * cos($0.phase) }
        var imaginary = components.map { $0.weight * sin($0.phase) }
        let stepReal = components.map { exp(-1 / ($0.decay * sampleRate)) * cos(2 * .pi * $0.frequency / sampleRate) }
        let stepImaginary = components.map { exp(-1 / ($0.decay * sampleRate)) * sin(2 * .pi * $0.frequency / sampleRate) }

        var output = [Float](repeating: 0, count: count)
        var brown = 0.0
        for n in 0..<count {
            let t = Double(n) / sampleRate
            var value = 0.0
            for k in components.indices {
                value += imaginary[k]
                let nextReal = real[k] * stepReal[k] - imaginary[k] * stepImaginary[k]
                imaginary[k] = real[k] * stepImaginary[k] + imaginary[k] * stepReal[k]
                real[k] = nextReal
            }
            value /= norm
            // Pick noise: ~15 ms of white noise with a fast decay.
            value += attackNoise * random.symmetric() * exp(-t / 0.004)
            // Room: white + a little low-frequency rumble, and 50 Hz hum with its 3rd harmonic.
            brown = 0.995 * brown + 0.05 * random.symmetric()
            let room = roomNoise * (random.symmetric() + brown)
            let mains = hum * (sin(2 * .pi * 50 * t) + 0.3 * sin(2 * .pi * 150 * t))
            output[n] = Float(amplitude * value + room + mains)
        }
        return output
    }

    /// Deterministic xorshift generator, so a failing case can be reproduced exactly.
    private struct Random {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func symmetric() -> Double { unit() * 2 - 1 }
    }
}
