import Foundation
import Testing
@testable import TunerCore

/// ADR 0008 rule 11: the noise gate judges the level of the band a string could occupy, not of the
/// room. Energy below every string of the tuning — mains hum, a fan, a desk — must neither open the
/// gate nor raise the floor that closes it.
@Suite("Presence meter")
struct PresenceMeterTests {
    private static let rate = 48_000.0
    private static let window = EngineParameters.standard.levelWindowDuration
    /// Bottom of standard tuning's detection range: E2 with the automatic search's head-room.
    private static let corner = Tuning.standard.detectionRange().lowerBound

    private func meter(corner: Double = PresenceMeterTests.corner) -> PresenceMeter {
        var meter = PresenceMeter()
        meter.prepare(corner: corner, sampleRate: Self.rate, windowDuration: Self.window)
        return meter
    }

    /// Steady-state level of a sine after the meter, in dB relative to its own RMS.
    private func response(at frequency: Double, of meter: PresenceMeter? = nil) -> Double {
        var meter = meter ?? self.meter()
        let tone = SignalGenerator.tone(frequency: frequency, sampleRate: Self.rate, duration: 2, harmonics: [1], amplitude: 0.5)
        meter.append(tone)      // the window keeps only the end, long after the filter has settled
        return 20 * log10(meter.level / (0.5 / 2.squareRoot()))
    }

    @Test("The Butterworth section Q values are the ones the response needs")
    func sectionQs() {
        #expect(PresenceMeter.sectionQs.count == PresenceMeter.order / 2)
        // The 4th-order pair is the textbook one, and `PartialFilter` hardcodes it.
        let fourth = (0..<2).map { 1 / (2 * cos(Double(2 * $0 + 1) * .pi / 8)) }
        #expect(zip(fourth, [0.541_196_100_146_197, 1.306_562_964_876_376]).allSatisfy { abs($0 - $1) < 1e-12 })
        #expect(PresenceMeter.sectionQs.allSatisfy { $0 > 0.5 })
        #expect(PresenceMeter.sectionQs == PresenceMeter.sectionQs.sorted(), "sections run from the gentlest pole outwards")
    }

    @Test("Mains hum below the lowest string is removed; the strings themselves are not")
    func response() {
        #expect(response(at: 50) < -18, "50 Hz hum: \(response(at: 50)) dB")
        #expect(response(at: 60) < -7, "60 Hz hum: \(response(at: 60)) dB")
        // Every string of standard tuning keeps essentially all of its level; the lowest pays the most.
        for note in Tuning.standard.strings {
            #expect(response(at: note.frequency()) > -0.3, "\(note.frequency()) Hz loses \(response(at: note.frequency())) dB")
        }
        #expect(response(at: 330) > -0.05, "the top string must be untouched: \(response(at: 330)) dB")
    }

    /// Losing the filter must cost sensitivity, not the tuner: the level is then the raw one.
    @Test("A corner that is not a usable frequency leaves the level unfiltered")
    func impossibleCorners() {
        let filtered = response(at: 50)
        for corner in [Self.rate * 0.45, 0, -60, .nan, .infinity] {
            let meter = meter(corner: corner)
            #expect(meter.corner == nil, "\(corner) Hz must not be designed into a filter")
            #expect(response(at: 50, of: meter) > filtered + 15, "an unfiltered level keeps the 50 Hz hum")
        }
        #expect(meter().corner == Self.corner)
    }

    /// A rate or a window no audio device would ask for must not trap on the way to an `Int`.
    @Test("An impossible sample rate or window leaves it unprepared rather than trapping")
    func impossibleRates() {
        for (rate, window) in [(Double.infinity, Self.window), (.nan, Self.window), (0, Self.window),
                               (Self.rate, .infinity), (Self.rate, .nan), (Self.rate, 0)] {
            var meter = PresenceMeter()
            meter.prepare(corner: Self.corner, sampleRate: rate, windowDuration: window)
            #expect(meter.corner == nil, "\(rate) Hz / \(window) s must not be designed into a filter")
            meter.append([0.1, -0.1, 0.1, -0.1])
            #expect(meter.level > 0, "it must still measure something")
        }
        // A rate no device reports but that is still a number: the window is clamped, not trapped, and
        // the corner is far below the Nyquist frequency, so a filter is designed as asked.
        var extreme = PresenceMeter()
        extreme.prepare(corner: Self.corner, sampleRate: .greatestFiniteMagnitude, windowDuration: Self.window)
        #expect(extreme.corner == Self.corner)
        extreme.append([0.1, -0.1])
        #expect(extreme.level.isFinite)
    }

    @Test("An empty window has no level")
    func emptyWindow() {
        #expect(meter().level == 0)
        #expect(PresenceMeter().level == 0, "before it is prepared too")
    }

    @Test("The level does not depend on how the stream is cut into chunks", arguments: [[128], [1_024], [17, 4_800, 333]])
    func chunkInvariance(sizes: [Int]) {
        let signal = StringModel(roomNoise: 0.001, hum: 0.002, amplitude: 0.1)
            .pluck(frequency: 110, sampleRate: Self.rate, duration: 1)
        var whole = meter()
        whole.append(signal)
        var chunked = meter()
        var index = 0, next = 0
        while index < signal.count {
            let stop = min(index + sizes[next % sizes.count], signal.count)
            next += 1
            chunked.append(Array(signal[index..<stop]))
            index = stop
        }
        #expect(chunked.level == whole.level)
    }

    @Test("A copy is an independent meter, and reset forgets the stream")
    func valueSemantics() {
        let signal = SignalGenerator.tone(frequency: 110, sampleRate: Self.rate, duration: 0.2, harmonics: [1], amplitude: 0.5)
        var original = meter()
        original.append(signal)
        var copy = original
        copy.append(signal)
        let beforeCopyGrew = original.level
        #expect(copy.level != 0)
        #expect(original.level == beforeCopyGrew, "feeding the copy must not touch the original")

        original.reset()
        #expect(original.level == 0)
        var fresh = meter()
        original.append(signal)
        fresh.append(signal)
        #expect(original.level == fresh.level, "reset must restore the initial state")
    }
}
