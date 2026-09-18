import Foundation

// MARK: - Configuration

/// Which string the user wants to tune.
public enum StringTarget: Sendable, Hashable {
    /// Detect the string automatically from the played pitch.
    case automatic
    /// Compare against one specific string (index into ``Tuning/strings``).
    case string(Int)
}

/// Everything the engine needs to interpret a pitch. Cheap to copy and compare.
public struct TunerConfiguration: Sendable, Hashable {
    public var tuning: Tuning
    public var referenceA: Double
    public var target: StringTarget

    public init(
        tuning: Tuning = .standard,
        referenceA: Double = PitchMath.standardReferenceA,
        target: StringTarget = .automatic
    ) {
        self.tuning = tuning
        self.referenceA = PitchMath.validReferenceA(referenceA)
        self.target = target
    }
}

/// Tunable thresholds of the analysis pipeline. All durations are in seconds so that behaviour
/// does not depend on the device sample rate.
public struct EngineParameters: Sendable, Hashable {
    /// Time between two analyses.
    public var hopDuration: Double = 0.025
    /// RMS above which the noise gate opens.
    public var gateOpenLevel: Double = 0.004
    /// RMS below which an open gate closes (hysteresis avoids chatter).
    public var gateCloseLevel: Double = 0.0025
    /// Minimum ``PitchEstimate/clarity`` accepted.
    public var minimumClarity: Double = 0.55
    /// Deviations beyond this many cents from the target string are ignored.
    public var maximumDeviation: Double = 300
    /// A jump larger than this many cents restarts smoothing instead of averaging.
    public var smoothingResetJump: Double = 60
    /// Smoothing factor range (higher clarity → less smoothing).
    public var smoothingFactor: ClosedRange<Double> = 0.25...0.7
    /// Deviation (cents) inside which a string counts as in tune.
    public var inTuneThreshold: Double = 5
    /// Extra tolerance before an in-tune string is considered out of tune again.
    public var inTuneExitMargin: Double = 2
    /// Consecutive in-tune analyses required to declare "in tune".
    public var stableHopsRequired: Int = 6
    /// How long the last reading stays visible after the signal fades.
    public var holdDuration: Double = 0.8
    /// A level rise by this factor counts as a new pluck (which may be a different string).
    public var attackRatio: Double = 1.5
    /// Within this many cents of an exact octave of the note being followed, a detection without a
    /// new pluck is treated as an octave error and folded back.
    public var octaveContinuityWindow: Double = 35
    /// Weight of each new measurement in the running inharmonicity correction.
    public var correctionSmoothing: Double = 0.15

    public static let standard = EngineParameters()

    public init() {}
}

// MARK: - Output

/// A single interpreted pitch reading.
public struct TunerReading: Sendable, Hashable {
    /// Detected frequency after octave correction (Hz).
    public var frequency: Double
    /// Frequency the string should have (Hz).
    public var targetFrequency: Double
    /// Index of the target string inside the tuning.
    public var stringIndex: Int
    /// Note of the target string.
    public var note: Note
    /// Smoothed deviation from the target in cents (positive = sharp).
    public var cents: Double
    /// Detector confidence, `0...1`.
    public var clarity: Double
    /// `true` once the deviation stayed inside the in-tune window long enough.
    public var isInTune: Bool
    /// `true` while an old reading is kept on screen after the signal has faded.
    public var isHeld: Bool
}

/// Result of one analysis step.
public struct TunerFrame: Sendable, Hashable {
    /// RMS level of the analysed window, `0...1`.
    public var level: Double
    /// Whether the noise gate is open (something audible is being played).
    public var isSignalPresent: Bool
    /// Current reading, `nil` when nothing (or nothing valid) is being played.
    public var reading: TunerReading?
}

// MARK: - Engine

/// Deterministic, hardware-independent tuning pipeline:
/// ring buffer → noise gate → YIN → string selection → low-partial refinement → smoothing →
/// stability → hold.
///
/// Feed it consecutive audio chunks with ``process(_:sampleRate:)``. It performs no I/O, so the
/// whole behaviour is unit-testable with synthetic signals. It owns a ``PitchDetector`` and is
/// therefore confined to a single isolation domain (it is not `Sendable`).
public struct TuningEngine {
    public private(set) var configuration: TunerConfiguration
    public let parameters: EngineParameters

    /// Sample rates the engine accepts (Hz). Everything from telephone-band to 384 kHz interfaces.
    public static let supportedSampleRates: ClosedRange<Double> = 8_000...384_000

    private var sampleRate: Double = 0
    private var detector: PitchDetector?
    private var buffer: [Float] = []
    /// One streaming low-pass per string and the matching history, for the refinement pass.
    private var partialFilters: [PartialFilter?] = []
    private var filtered: [[Float]] = []
    /// Samples the filters have processed since they were created; they need a moment to settle.
    private var filteredSampleCount = 0
    private var samplesSinceAnalysis = 0

    private var gateOpen = false
    private var level = 0.0
    private var smoothedCents = 0.0
    private var stableCount = 0
    private var inTune = false
    private var lastReading: TunerReading?
    /// Level of the previous analysis, to tell a new pluck from a decaying one.
    private var previousLevel = 0.0
    /// Inharmonicity correction (cents) of the string being followed. It is a property of the
    /// string, stable over a pluck, while each single measurement of it is noisy (hum and rumble
    /// share the fundamental's band), so it is averaged over time.
    private var inharmonicCorrection: (string: Int, cents: Double)?
    private var silentSamples = 0
    private var lastFrame = TunerFrame(level: 0, isSignalPresent: false, reading: nil)

    public init(configuration: TunerConfiguration = .init(), parameters: EngineParameters = .standard) {
        self.configuration = configuration
        self.parameters = parameters
    }

    /// Applies a new configuration. Changing tuning, A4 or target discards the current reading and
    /// rebuilds the detector, whose search range depends on all three.
    public mutating func reconfigure(_ newValue: TunerConfiguration) {
        guard newValue != configuration else { return }
        configuration = newValue
        resetReading()
        detector = nil
    }

    /// Clears smoothing, stability and the held reading (keeps buffered audio).
    public mutating func resetReading() {
        smoothedCents = 0
        stableCount = 0
        inTune = false
        lastReading = nil
        silentSamples = 0
        inharmonicCorrection = nil
    }

    /// Consumes a chunk of mono samples.
    ///
    /// - Returns: The most recent frame if at least one analysis hop elapsed, otherwise `nil`.
    public mutating func process(_ samples: [Float], sampleRate: Double) -> TunerFrame? {
        // Reject anything a real audio device never reports. Non-finite or absurd rates would otherwise
        // trap in an `Int` conversion or ask for gigabytes of scratch memory.
        guard Self.supportedSampleRates.contains(sampleRate), !samples.isEmpty else { return nil }
        if sampleRate != self.sampleRate {
            self.sampleRate = sampleRate
            detector = nil
            buffer.removeAll(keepingCapacity: true)
            samplesSinceAnalysis = 0
            resetReading()
        }
        if detector == nil {
            detector = PitchDetector(sampleRate: sampleRate, frequencyRange: searchRange())
            partialFilters = configuration.tuning.strings.map {
                PartialFilter(frequency: $0.frequency(referenceA: configuration.referenceA), sampleRate: sampleRate)
            }
            filtered = Array(repeating: [], count: partialFilters.count)
            filteredSampleCount = 0
        }
        guard let detector else { return nil }

        buffer.append(contentsOf: samples)
        let capacity = detector.requiredSampleCount
        if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
        for index in partialFilters.indices {
            guard let filter = partialFilters[index] else { continue }
            filtered[index].append(contentsOf: filter.process(samples))
            if filtered[index].count > capacity { filtered[index].removeFirst(filtered[index].count - capacity) }
        }
        filteredSampleCount += samples.count
        samplesSinceAnalysis += samples.count

        let hop = max(1, Int(sampleRate * parameters.hopDuration))
        guard buffer.count >= capacity, samplesSinceAnalysis >= hop else { return nil }

        // The buffer only ever holds the newest window, so one analysis per call is equivalent to
        // one per elapsed hop; `hops` keeps the hold/stability timers accurate.
        let hops = max(1, samplesSinceAnalysis / hop)
        samplesSinceAnalysis -= hops * hop
        return analyse(detector: detector, hops: hops, hop: hop)
    }

    // MARK: - Analysis step

    private mutating func analyse(detector: PitchDetector, hops: Int, hop: Int) -> TunerFrame {
        let window = buffer.suffix(min(buffer.count, 2048))
        var sumSquares = 0.0
        for sample in window { sumSquares += Double(sample) * Double(sample) }
        level = (sumSquares / Double(window.count)).squareRoot()

        gateOpen = gateOpen ? level > parameters.gateCloseLevel : level > parameters.gateOpenLevel
        let elapsed = hops * hop
        let isNewPluck = level > previousLevel * parameters.attackRatio
        previousLevel = level

        guard gateOpen else {
            return finish(withDetection: nil, elapsedSamples: elapsed)
        }

        guard let estimate = detector.estimate(in: buffer),
              estimate.clarity >= parameters.minimumClarity,
              var selection = select(for: followingOctave(of: estimate.frequency, isNewPluck: isNewPluck)),
              abs(selection.cents) <= parameters.maximumDeviation
        else {
            return finish(withDetection: nil, elapsedSamples: elapsed)
        }
        // Measure the fundamental itself, free of the upper partials' inharmonic pull.
        // The filters' start-up transient must have left the window before it can be measured.
        if filtered.indices.contains(selection.index), filteredSampleCount >= 2 * detector.requiredSampleCount {
            let correction = inharmonicityCorrection(
                measured: detector.refine(selection.frequency, lowPassed: filtered[selection.index]),
                estimate: selection.frequency,
                string: selection.index
            )
            let target = configuration.tuning.strings[selection.index].frequency(referenceA: configuration.referenceA)
            selection.frequency *= pow(2, correction / 1200)
            selection.cents = PitchMath.cents(from: selection.frequency, to: target)
        }

        // Smooth the deviation; restart on string change or a large jump.
        let previousIndex = lastReading?.stringIndex
        if previousIndex != selection.index || lastReading?.isHeld == true
            || abs(selection.cents - smoothedCents) > parameters.smoothingResetJump {
            smoothedCents = selection.cents
            stableCount = 0
            inTune = false
        } else {
            let range = parameters.smoothingFactor
            let alpha = range.lowerBound + (range.upperBound - range.lowerBound) * estimate.clarity
            smoothedCents = alpha * selection.cents + (1 - alpha) * smoothedCents
        }

        // Stability with hysteresis.
        let magnitude = abs(smoothedCents)
        if inTune {
            if magnitude > parameters.inTuneThreshold + parameters.inTuneExitMargin {
                inTune = false
                stableCount = 0
            }
        } else if magnitude <= parameters.inTuneThreshold {
            stableCount += hops
            if stableCount >= parameters.stableHopsRequired { inTune = true }
        } else {
            stableCount = 0
        }

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

    private mutating func finish(withDetection reading: TunerReading?, elapsedSamples: Int) -> TunerFrame {
        if let reading {
            silentSamples = 0
            lastReading = reading
            lastFrame = TunerFrame(level: level, isSignalPresent: true, reading: reading)
            return lastFrame
        }

        silentSamples += elapsedSamples
        let holdSamples = Int(parameters.holdDuration * sampleRate)
        if var held = lastReading, silentSamples <= holdSamples {
            held.isHeld = true
            lastReading = held
            lastFrame = TunerFrame(level: level, isSignalPresent: gateOpen, reading: held)
        } else {
            resetReading()
            lastFrame = TunerFrame(level: level, isSignalPresent: gateOpen, reading: nil)
        }
        return lastFrame
    }

    /// Running inharmonicity correction, in cents, for `string`, updated with one refined measurement.
    private mutating func inharmonicityCorrection(measured: Double, estimate: Double, string: Int) -> Double {
        let sample = PitchMath.cents(from: measured, to: estimate)
        let refinementFailed = measured == estimate
        guard let current = inharmonicCorrection, current.string == string else {
            let initial = refinementFailed ? 0 : sample
            inharmonicCorrection = (string, initial)
            return initial
        }
        guard !refinementFailed else { return current.cents }
        let updated = current.cents + parameters.correctionSmoothing * (sample - current.cents)
        inharmonicCorrection = (string, updated)
        return updated
    }

    /// A string that is dying away keeps its octave. As the note decays into noise and hum, YIN can
    /// latch onto two to four times the period (or a half to a quarter of it), which in automatic
    /// mode would jump to another string. Without a new pluck, a detection at such a ratio from the note
    /// being followed is folded back onto it.
    private func followingOctave(of frequency: Double, isNewPluck: Bool) -> Double {
        guard !isNewPluck, let last = lastReading else { return frequency }
        for ratio in 2...4 {
            for factor in [Double(ratio), 1 / Double(ratio)] {
                let folded = frequency * factor
                if abs(PitchMath.cents(from: folded, to: last.frequency)) < parameters.octaveContinuityWindow {
                    return folded
                }
            }
        }
        return frequency
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
            return (target * 0.7)...(target * 1.5)
        }
    }

    // MARK: - String selection

    private struct Selection {
        var frequency: Double
        var index: Int
        var cents: Double
    }

    /// Maps a detected frequency to a string of the configured tuning.
    private func select(for frequency: Double) -> Selection? {
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
