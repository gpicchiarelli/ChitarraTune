import Foundation

// MARK: - Engine

/// Deterministic, hardware-independent tuning pipeline:
/// sliding analysis window → noise gate → YIN → string selection → low-partial refinement → smoothing →
/// stability → hold.
///
/// Feed it consecutive audio chunks with ``process(_:sampleRate:)``. It performs no I/O, so the
/// whole behaviour is unit-testable with synthetic signals. It owns a ``PitchDetector`` and is
/// therefore confined to a single isolation domain (it is not `Sendable`).
public struct TuningEngine {
    public private(set) var configuration: TunerConfiguration
    public let parameters: EngineParameters

    /// Search range around a pinned string, as frequency ratios (−617 … +702 cents): wide enough for a
    /// badly detuned string, narrow enough that its upper partials cannot win.
    public static let pinnedSearchSpan: ClosedRange<Double> = 0.7...1.5

    /// Sample rates the engine accepts (Hz). Everything from telephone-band to 384 kHz interfaces.
    public static let supportedSampleRates: ClosedRange<Double> = 8_000...384_000

    private var sampleRate: Double = 0
    /// The detector is a reference type — it owns an FFT plan and scratch memory — living inside a
    /// value type. Two copies of an engine sharing one would be one instrument again, and the test
    /// that says they are not (`EngineValueSemanticsTests`) would keep passing right up until the day
    /// the detector kept something between calls. So a copy takes its own: the box is checked for
    /// uniqueness before each analysis and replaced when it turns out to be shared, which costs one
    /// FFT plan per copy of the engine and nothing at all per chunk.
    private final class DetectorBox {
        let detector: PitchDetector
        init(_ detector: PitchDetector) { self.detector = detector }
    }
    private var detectorBox: DetectorBox?
    /// `true` once building a detector for the current configuration and sample rate has failed, so
    /// it is not retried (together with the string filters) on every chunk.
    private var detectorUnavailable = false
    /// The newest ``PitchDetector/requiredSampleCount`` samples: a sliding window that drops its
    /// oldest samples as new ones arrive (a copy of a few kilobytes per chunk, negligible next to the
    /// analysis itself).
    private var buffer: [Float] = []
    /// One streaming low-pass per string and the matching history, for the refinement pass.
    ///
    /// All strings are filtered even when one is pinned: switching back to automatic, or to another
    /// string, then finds settled filter history and the fundamental can be refined at once. The whole
    /// engine stays under 3 % of real time, the ceiling `RealTimeBudgetTests` enforces, so saving five
    /// filters is not worth a measurement that briefly loses its refinement.
    ///
    /// That was prose for a while: ``reconfigure(_:)`` dropped the detector, and the rebuild below
    /// rebuilt every filter along with it, so pinning a string threw away exactly the settled history
    /// this paragraph promises. `filterBasis` is what makes it true — a filter is redesigned when
    /// the tuning, the reference pitch or the sample rate changes, and not because the user picked a
    /// different string to look at.
    private var partialFilters: [PartialFilter?] = []
    private var filtered: [[Float]] = []
    /// Tuning and reference pitch the string filters and the level meter were designed for. The
    /// target is deliberately not part of it: pinning a string changes which one is followed, not
    /// what any filter has to pass.
    private var filterBasis: (tuning: Tuning, referenceA: Double)?
    /// The level the gate judges, in the band a string of this tuning could occupy (``PresenceMeter``).
    private var presence = PresenceMeter()
    /// Samples the filters have processed since they were created; they need a moment to settle.
    private var filteredSampleCount = 0
    /// Samples since the last attack (a new pluck, or the start of the filtered stream): the string
    /// filters ring for a while after one, and the refinement waits for them (ADR 0008).
    private var samplesSinceAttack = 0
    private var samplesSinceAnalysis = 0
    /// Where the next chunk should start on the device timeline, if the source reports timestamps.
    private var nextSampleTime: Int64?

    private var gate: NoiseGate
    private var level = 0.0
    private var smoothedCents = 0.0
    private var stableCount = 0
    private var inTune = false
    private var lastReading: TunerReading?
    /// Level of the previous analysis, to tell a new pluck from a decaying one.
    private var previousLevel = 0.0
    private var inharmonicity = InharmonicityTracker()
    /// Analyses performed so far and why some produced no reading, for diagnostics.
    public private(set) var counts = AnalysisCounts()
    private var silentSamples = 0

    public init(configuration: TunerConfiguration = .init(), parameters: EngineParameters = .standard) {
        self.configuration = configuration
        self.parameters = parameters
        gate = NoiseGate(parameters: parameters)
    }

    /// Applies a new configuration. Changing tuning, A4 or target discards the current reading and
    /// rebuilds the detector, whose search range depends on all three.
    public mutating func reconfigure(_ newValue: TunerConfiguration) {
        guard newValue != configuration else { return }
        configuration = newValue
        resetReading()
        detectorBox = nil
        detectorUnavailable = false
    }

    /// Forgets buffered audio and filter state after a discontinuity in the stream.
    private mutating func discardHistory() {
        buffer.removeAll(keepingCapacity: true)
        for index in filtered.indices { filtered[index].removeAll(keepingCapacity: true) }
        for index in partialFilters.indices { partialFilters[index]?.reset() }
        presence.reset()
        filteredSampleCount = 0
        samplesSinceAttack = 0
        samplesSinceAnalysis = 0
        // The attack test compares this analysis with the previous one. Across a gap there is no
        // previous one: the meter's filter restarts from zero and under-reports while it settles, so
        // a level from before the gap would read as a decay that never happened. Zero makes whatever
        // comes back a new pluck, which is what `samplesSinceAttack = 0` above already assumes.
        previousLevel = 0
        // The noise floor is deliberately kept: it describes the room, and a dropped buffer says
        // nothing about the room. Relearning it would put the gate back at its loud-room level and
        // stop hearing a soft source that was being heard a moment earlier.
    }

    /// Clears smoothing, stability and the held reading (keeps buffered audio).
    public mutating func resetReading() {
        smoothedCents = 0
        stableCount = 0
        inTune = false
        lastReading = nil
        silentSamples = 0
        inharmonicity = InharmonicityTracker()
    }

    /// Consumes a chunk of mono samples.
    ///
    /// - Parameter sampleTime: Position of the first sample on the source's timeline, if known. When
    ///   it does not follow on from the previous chunk, audio was lost: the analysis window and the
    ///   string filters would otherwise splice two unrelated stretches of signal and measure a
    ///   period that never existed, so the history is discarded (a held reading stays on screen).
    /// - Returns: The frame of the last analysis that fell inside this chunk, or `nil` if none did.
    ///   The analyses themselves do not depend on how the stream is split into chunks.
    public mutating func process(_ samples: [Float], sampleRate: Double, sampleTime: Int64? = nil) -> TunerFrame? {
        // Reject anything a real audio device never reports. Non-finite or absurd rates would otherwise
        // trap in an `Int` conversion or ask for gigabytes of scratch memory.
        guard Self.supportedSampleRates.contains(sampleRate), !samples.isEmpty else { return nil }
        if sampleRate != self.sampleRate {
            self.sampleRate = sampleRate
            detectorBox = nil
            filterBasis = nil
            buffer.removeAll(keepingCapacity: true)
            samplesSinceAnalysis = 0
            nextSampleTime = nil
            detectorUnavailable = false
            resetReading()
        }
        if let sampleTime {
            if let expected = nextSampleTime, sampleTime != expected {
                counts.discontinuities += 1
                discardHistory()
            }
            nextSampleTime = sampleTime + Int64(samples.count)
        }
        // A non-finite sample is not audio. Fed to the filters it would stay in their state for ever:
        // every later output NaN, the refinement silently declining, and a low string reading 3 cents
        // sharp with nothing on screen to say so. Dropped like audio lost between two callbacks.
        //
        // One pass over the chunk, in Swift, on a path that already runs about thirty biquads per
        // sample in double precision a few lines further down: it is a thirtieth of the arithmetic
        // beside it at the very most, and the whole engine sits at a fifth of its budget
        // (`RealTimeBudgetTests`). Accelerate has no "is any of this non-finite", and reaching for a
        // sum to infer one would answer a different question on an input large enough to overflow.
        if samples.contains(where: { !$0.isFinite }) {
            counts.discontinuities += 1
            discardHistory()
            return nil
        }
        // A shared box means this engine was copied: take a detector of our own before touching its
        // scratch memory. The filters below are value types and have already copied themselves.
        if detectorBox != nil, !isKnownUniquelyReferenced(&detectorBox) { detectorBox = nil }
        if detectorBox == nil, !detectorUnavailable {
            detectorBox = PitchDetector(sampleRate: sampleRate, frequencyRange: searchRange()).map(DetectorBox.init)
            detectorUnavailable = detectorBox == nil
            if filterBasis?.tuning != configuration.tuning || filterBasis?.referenceA != configuration.referenceA {
                rebuildFilters()
                filterBasis = (configuration.tuning, configuration.referenceA)
            }
        }
        guard let detector = detectorBox?.detector else { return nil }

        // Analyse at the same sample positions however the stream is cut into chunks: a device that
        // delivers 100 ms at a time must get the same stability count, smoothing and readings as one
        // that delivers 20 ms. The chunk is fed in slices that end exactly where an analysis is due.
        let hop = max(1, Int(sampleRate * parameters.hopDuration))
        let capacity = detector.requiredSampleCount
        var frame: TunerFrame?
        var start = samples.startIndex
        while start < samples.endIndex {
            let due = buffer.count < capacity ? max(capacity - buffer.count, hop - samplesSinceAnalysis) : hop - samplesSinceAnalysis
            let end = min(samples.endIndex, start + max(1, due))
            append(Array(samples[start..<end]), capacity: capacity)
            start = end
            guard buffer.count >= capacity, samplesSinceAnalysis >= hop else { continue }
            // Before the window first fills, several hops pass without an analysis; `hops` keeps the
            // hold timer accurate. From then on every analysis is exactly one hop after the previous.
            let hops = samplesSinceAnalysis / hop
            samplesSinceAnalysis -= hops * hop
            frame = analyse(detector: detector, hops: hops, hop: hop)
        }
        return frame
    }

    /// Designs one low-pass per string of the tuning and the level meter's high-pass, and forgets
    /// everything they had heard: their state belongs to the filters that have just been replaced.
    private mutating func rebuildFilters() {
        partialFilters = configuration.tuning.strings.map {
            PartialFilter(frequency: $0.frequency(referenceA: configuration.referenceA), sampleRate: sampleRate)
        }
        filtered = Array(repeating: [], count: partialFilters.count)
        presence.prepare(
            corner: configuration.tuning.detectionRange(referenceA: configuration.referenceA).lowerBound,
            sampleRate: sampleRate,
            windowDuration: parameters.levelWindowDuration
        )
        filteredSampleCount = 0
        samplesSinceAttack = 0
        previousLevel = 0
    }

    private mutating func append(_ samples: [Float], capacity: Int) {
        buffer.append(contentsOf: samples)
        if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
        for index in partialFilters.indices {
            guard let output = partialFilters[index]?.process(samples) else { continue }
            filtered[index].append(contentsOf: output)
            if filtered[index].count > capacity { filtered[index].removeFirst(filtered[index].count - capacity) }
        }
        presence.append(samples)
        filteredSampleCount += samples.count
        samplesSinceAttack += samples.count
        samplesSinceAnalysis += samples.count
    }

    // MARK: - Analysis step

    private mutating func analyse(detector: PitchDetector, hops: Int, hop: Int) -> TunerFrame {
        counts.analyses += 1
        level = presence.level
        let elapsed = hops * hop
        gate.update(level: level, elapsed: Double(elapsed) / sampleRate)
        let isNewPluck = level > previousLevel * parameters.attackRatio
        if isNewPluck { samplesSinceAttack = 0 }
        previousLevel = level

        guard gate.isOpen else {
            counts.belowGate += 1
            return finish(withDetection: nil, elapsedSamples: elapsed)
        }
        guard let estimate = detector.estimate(in: buffer), estimate.clarity >= parameters.minimumClarity else {
            counts.unclear += 1
            return finish(withDetection: nil, elapsedSamples: elapsed)
        }
        var selection = select(for: followingOctave(of: estimate.frequency, isNewPluck: isNewPluck))
        guard abs(selection.cents) <= parameters.maximumDeviation else {
            counts.outOfRange += 1
            return finish(withDetection: nil, elapsedSamples: elapsed)
        }
        let correction = correct(&selection, detector: detector)
        smooth(selection.cents, string: selection.index, clarity: estimate.clarity, correction: correction)
        updateStability()

        let note = configuration.tuning.strings[selection.index]
        let reading = TunerReading(
            frequency: selection.frequency,
            targetFrequency: note.frequency(referenceA: configuration.referenceA),
            stringIndex: selection.index,
            note: note,
            cents: smoothedCents,
            clarity: estimate.clarity,
            isInTune: inTune,
            isHeld: false
        )
        return finish(withDetection: reading, elapsedSamples: elapsed)
    }

    // MARK: - Correction, smoothing, stability

    /// Measures the fundamental itself, free of the upper partials' inharmonic pull, and applies the
    /// running correction to `selection`. Returns the correction, in cents.
    ///
    /// The string filter rings after an attack (its hum notches longest): the window must hold only
    /// its settled response, otherwise the ringing is measured as a correction and lingers in the
    /// running average for half a second. While the filter settles after a re-pluck, the string keeps
    /// the correction already known.
    private mutating func correct(_ selection: inout Selection, detector: PitchDetector) -> Double {
        var correction = 0.0
        if filtered.indices.contains(selection.index), let filter = partialFilters[selection.index],
           filteredSampleCount >= 2 * detector.requiredSampleCount,
           samplesSinceAttack >= filter.settlingSamples + detector.requiredSampleCount {
            correction = inharmonicity.update(
                measured: detector.refine(selection.frequency, lowPassed: filtered[selection.index]),
                estimate: selection.frequency,
                string: selection.index,
                weight: parameters.weight(parameters.correctionSmoothing)
            )
        } else if let known = inharmonicity.known(for: selection.index) {
            correction = known
        }
        if correction != 0 {
            let target = configuration.tuning.strings[selection.index].frequency(referenceA: configuration.referenceA)
            selection.frequency *= pow(2, correction / 1200)
            selection.cents = PitchMath.cents(from: selection.frequency, to: target)
        }
        return correction
    }

    /// Smooths the deviation of the string being followed; restarts on a string change, after a held
    /// reading or on a large jump.
    private mutating func smooth(_ cents: Double, string: Int, clarity: Double, correction: Double) {
        guard let last = lastReading, last.stringIndex == string, !last.isHeld,
              abs(cents - smoothedCents) <= parameters.smoothingResetJump else {
            smoothedCents = cents
            stableCount = 0
            inTune = false
            inharmonicity.applied = correction
            return
        }
        // The correction is an offset of the instrument, not an observation: when it changes, the
        // history averaged so far was measured with the old one and moves with it, instead of
        // dragging the reading towards uncorrected values for several analyses.
        smoothedCents += correction - inharmonicity.applied
        inharmonicity.applied = correction
        let range = parameters.smoothingFactor
        let alpha = parameters.weight(range.lowerBound + (range.upperBound - range.lowerBound) * clarity)
        smoothedCents = alpha * cents + (1 - alpha) * smoothedCents
    }

    /// "In tune" with hysteresis, counted in real analyses (ADR 0008 rule 6).
    ///
    /// One analysis is one count. It used to add the number of hops that had gone by, which is the
    /// same thing once the window is full and is not while it is filling: the first analysis of a
    /// session arrives two hops after the previous one and was credited with both, so "in tune"
    /// could be declared on five analyses of evidence instead of six.
    private mutating func updateStability() {
        let magnitude = abs(smoothedCents)
        if inTune {
            if magnitude > parameters.inTuneThreshold + parameters.inTuneExitMargin {
                inTune = false
                stableCount = 0
            }
        } else if magnitude <= parameters.inTuneThreshold {
            stableCount += 1
            if stableCount >= parameters.stableAnalysesRequired { inTune = true }
        } else {
            stableCount = 0
        }
    }

    private mutating func finish(withDetection reading: TunerReading?, elapsedSamples: Int) -> TunerFrame {
        if let reading {
            silentSamples = 0
            lastReading = reading
            return TunerFrame(level: level, isSignalPresent: true, reading: reading)
        }

        silentSamples += elapsedSamples
        let holdSamples = Int(parameters.holdDuration * sampleRate)
        if var held = lastReading, silentSamples <= holdSamples {
            held.isHeld = true
            lastReading = held
            return TunerFrame(level: level, isSignalPresent: gate.isOpen, reading: held)
        } else {
            resetReading()
            return TunerFrame(level: level, isSignalPresent: gate.isOpen, reading: nil)
        }
    }

    /// A string that is dying away keeps its octave. As the note decays into noise and hum, YIN can
    /// latch onto two to four times the period (or a half to a quarter of it), which in automatic
    /// mode would jump to another string. Without a new pluck, a detection at such a ratio from the note
    /// being followed is folded back onto it, but only when the spectrum agrees that it is an error:
    /// folding *down* needs the followed note's fundamental to still be there (otherwise a higher
    /// string was played), folding *up* needs the detected lower note to be absent (otherwise a lower
    /// string was played softly, with no attack to announce it).
    private func followingOctave(of frequency: Double, isNewPluck: Bool) -> Double {
        guard !isNewPluck, let last = lastReading else { return frequency }
        for ratio in 2...4 {
            for factor in [Double(ratio), 1 / Double(ratio)] {
                let folded = frequency * factor
                guard abs(PitchMath.cents(from: folded, to: last.frequency)) < parameters.octaveContinuityWindow else { continue }
                let isDetectorError = factor > 1
                    ? !lowerNoteIsPresent(at: frequency, below: last.frequency)
                    : fundamentalIsPresent(at: last.frequency)
                if isDetectorError { return folded }
            }
        }
        return frequency
    }

    /// Whether the followed note's fundamental still carries a real share of the signal: its amplitude
    /// at exactly that frequency (one Hann-windowed DFT bin, Goertzel) against the window's RMS. A
    /// harmonic that YIN latched onto during a decay still has its fundamental underneath; a newly
    /// played string an octave or two higher has none. The analysis window spans several periods of
    /// the lowest string, so the neighbouring octave is well outside the bin's main lobe.
    private func fundamentalIsPresent(at frequency: Double) -> Bool {
        guard let tone = Spectrum.tone(at: frequency, in: buffer, sampleRate: sampleRate) else { return true }
        return tone.amplitude / 2.squareRoot() >= tone.rms * parameters.fundamentalPresenceRatio
    }

    /// Whether a note at `frequency`, an octave or two below the followed note, is really sounding:
    /// its amplitude against the followed note's own. Against the window's RMS (as for the followed
    /// note) would not do: a short window cannot separate 41 Hz from 50 Hz hum, so hum would count as
    /// a low E an octave down. A detector that took twice the period finds almost nothing there; a
    /// lower string played softly is at least as loud as what is left of the higher one.
    private func lowerNoteIsPresent(at frequency: Double, below followed: Double) -> Bool {
        guard let lower = Spectrum.tone(at: frequency, in: buffer, sampleRate: sampleRate),
              let upper = Spectrum.tone(at: followed, in: buffer, sampleRate: sampleRate) else { return true }
        return lower.amplitude >= upper.amplitude * parameters.lowerNotePresenceRatio
    }

    /// Frequencies the detector has to cover. When a string is pinned the search is narrowed
    /// around it: upper partials can no longer win (no octave errors by construction) and the
    /// analysis window shrinks for higher strings, which lowers latency and CPU cost.
    private func searchRange() -> ClosedRange<Double> {
        let tuning = configuration.tuning
        switch configuration.target {
        case .automatic:
            return tuning.detectionRange(referenceA: configuration.referenceA)
        case .string(let requested):
            let index = min(max(0, requested), tuning.stringCount - 1)
            let target = tuning.strings[index].frequency(referenceA: configuration.referenceA)
            return (target * Self.pinnedSearchSpan.lowerBound)...(target * Self.pinnedSearchSpan.upperBound)
        }
    }

    // MARK: - String selection

    private struct Selection {
        var frequency: Double
        var index: Int
        var cents: Double
    }

    /// Maps a detected frequency to a string of the configured tuning.
    private func select(for frequency: Double) -> Selection {
        let tuning = configuration.tuning
        let referenceA = configuration.referenceA

        switch configuration.target {
        case .automatic:
            let match = tuning.nearestString(to: frequency, referenceA: referenceA)
            return Selection(frequency: frequency, index: match.index, cents: match.cents)

        case .string(let requested):
            let index = min(max(0, requested), tuning.stringCount - 1)
            let target = tuning.strings[index].frequency(referenceA: referenceA)
            return Selection(frequency: frequency, index: index, cents: PitchMath.cents(from: frequency, to: target))
        }
    }
}
