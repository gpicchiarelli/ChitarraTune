import Foundation

/// The level the noise gate judges: the stream high-passed to the band where a string of the tuning
/// could be, measured as the RMS of its most recent window.
///
/// The gate decides from a level, and a level measured on the raw input is a level of whatever is in
/// the room. An amplifier that is merely switched on idles with mains hum, a computer has a fan, a
/// desk carries footsteps — energy at frequencies where no string of this tuning can be, however badly
/// it is tuned. The gate learns that energy as its noise floor and raises its threshold by the same
/// factor, so a string is masked by interference it does not share a single frequency with: an
/// amplifier idling 12 dB below a pluck stopped that pluck being heard at all, and the first field test
/// found the B and the top E immovable until the amplifier was turned up (``NoiseGate``).
///
/// Below the bottom of the detection range there is nothing to measure: the lowest string of the
/// tuning, 386 cents flat (the automatic search's head-room, ``Tuning/headroom``), is still above it.
/// Nothing here touches what is *measured* — a reading comes from the unfiltered window and its own
/// string filter — so this can only change whether a reading is produced, never its value.
///
/// The high-pass is an 8th-order Butterworth. Against standard tuning's 65.9 Hz corner a 50 Hz hum
/// loses 19 dB and a 60 Hz hum 7 dB, while the low E itself loses 0.1 dB: a Butterworth response is
/// maximally flat, so the steeper it is the less it costs the string it must keep. Drop C reaches
/// 52.3 Hz, where 50 Hz hum is inside the range the tuner must search and is left alone; there the hum
/// notches of the string filters are the only defence, as before.
///
/// Like ``PartialFilter`` the sections run on the continuous stream, in double precision, one sample
/// after the other, so the level depends only on the samples — not on how the device cut them into
/// chunks and not on the CPU. A value type: copying a ``TuningEngine`` copies its gate's meter too.
struct PresenceMeter: Sendable {
    /// Order of the Butterworth response. Eight costs four biquads per sample — a sixth of the engine's
    /// own budget — and rejects twice as many decibels of hum as four while taking less of the lowest
    /// string.
    static let order = 8

    /// Q of each second-order section of a Butterworth response of ``order``: the poles lie at equal
    /// angles on a semicircle, and each conjugate pair has `Q = 1 / (2·cos θ)`.
    static let sectionQs: [Double] = (0..<order / 2).map {
        1 / (2 * cos(Double(2 * $0 + 1) * .pi / Double(2 * order)))
    }

    /// Corner frequency (Hz), or `nil` when the level is measured unfiltered.
    private(set) var corner: Double?
    private var sections: [PartialFilter.Section] = []
    private var windowSamples = 1
    /// The newest ``windowSamples`` of the filtered stream.
    private var window: [Float] = []

    /// Designs the filter for one corner, sample rate and window, and forgets the stream so far.
    ///
    /// A corner that is not a usable frequency below the Nyquist frequency leaves the level unfiltered,
    /// exactly as it was measured before this meter existed: losing the filter must not stop the tuner
    /// measuring. The tuning catalog and ``TuningEngine/supportedSampleRates`` never produce one.
    mutating func prepare(corner: Double, sampleRate: Double, windowDuration: Double) {
        reset()
        guard sampleRate.isFinite, sampleRate > 0, windowDuration.isFinite, windowDuration > 0 else {
            (self.corner, sections, windowSamples) = (nil, [], 1)
            return
        }
        // Clamped because `Int(_:)` traps on anything an audio device would never ask for.
        windowSamples = max(1, Int(min(windowDuration * sampleRate, 1e7).rounded()))
        guard corner.isFinite, corner > 0, corner < sampleRate * 0.45 else {
            (self.corner, sections) = (nil, [])
            return
        }
        let omega = 2 * .pi * corner / sampleRate
        let cosine = cos(omega), sine = sin(omega)
        sections = Self.sectionQs.map { q in
            let alpha = sine / (2 * q)
            return PartialFilter.Section(b0: (1 + cosine) / 2, b1: -(1 + cosine), b2: (1 + cosine) / 2,
                                         a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha)
        }
        self.corner = corner
    }

    /// Filters the next chunk of the stream into the window.
    mutating func append(_ samples: [Float]) {
        let filtered = sections.isEmpty ? samples : sections.withUnsafeMutableBufferPointer { sections in
            samples.map { sample in
                var value = Double(sample)
                for index in sections.indices { value = sections[index](value) }
                return Float(value)
            }
        }
        window.append(contentsOf: filtered)
        if window.count > windowSamples { window.removeFirst(window.count - windowSamples) }
    }

    /// RMS of the window, or zero before any audio has arrived.
    var level: Double {
        guard !window.isEmpty else { return 0 }
        var sumSquares = 0.0
        for sample in window { sumSquares += Double(sample) * Double(sample) }
        return (sumSquares / Double(window.count)).squareRoot()
    }

    /// Forgets the filter state and the window (after a gap in the stream).
    mutating func reset() {
        for index in sections.indices { (sections[index].z1, sections[index].z2) = (0, 0) }
        window.removeAll(keepingCapacity: true)
    }
}
