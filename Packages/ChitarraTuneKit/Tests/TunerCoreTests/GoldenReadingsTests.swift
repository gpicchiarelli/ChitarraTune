import Foundation
import Testing
@testable import TunerCore

/// Freezes what the instrument *measures*. For a fixed set of deterministic signals (every string of
/// every tuning, detuned, at three sample rates, as a harmonic tone and as an inharmonic plucked
/// string with noise and hum) it records every frame the engine produces — level, gate, frequency,
/// cents, string, clarity, in-tune, held — and compares them with `Fixtures/golden-readings.txt`.
///
/// A refactor must reproduce them exactly. If a change is *meant* to alter a measurement, regenerate
/// the file with `UPDATE_GOLDEN=1 swift test --filter GoldenReadings`, and explain in the commit why
/// the new numbers are more correct. Never regenerate just to make the test pass.
@Suite("Golden readings")
struct GoldenReadingsTests {
    static let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/golden-readings.txt")

    struct Case: Sendable, CustomTestStringConvertible {
        let tuning: TuningID, string: Int, cents: Double, rate: Double, plucked: Bool
        var name: String { "\(tuning.rawValue)/\(string)/\(cents)/\(Int(rate))/\(plucked ? "plucked" : "tone")" }
        var testDescription: String { name }
    }

    static let cases: [Case] = {
        var all: [Case] = []
        for tuning in TuningID.allCases {
            for string in 0..<6 {
                all.append(Case(tuning: tuning, string: string, cents: 0, rate: 44_100, plucked: false))
                all.append(Case(tuning: tuning, string: string, cents: -23, rate: 48_000, plucked: true))
                if tuning == .standard {
                    all.append(Case(tuning: tuning, string: string, cents: +11, rate: 96_000, plucked: true))
                    all.append(Case(tuning: tuning, string: string, cents: +4, rate: 44_100, plucked: true))
                }
            }
        }
        return all
    }()

    /// Canonical text of every frame for one case, and its fresh (non-held) readings.
    static func render(_ c: Case) -> (text: String, readings: [TunerReading]) {
        let tuning = Tuning.tuning(for: c.tuning)
        let f0 = tuning.strings[c.string].frequency() * pow(2, c.cents / 1200)
        let signal: [Float] = c.plucked
            ? StringModel().pluck(frequency: f0, sampleRate: c.rate, duration: 0.8)
            : SignalGenerator.tone(frequency: f0, sampleRate: c.rate, duration: 0.8, harmonics: SignalGenerator.guitarHarmonics, amplitude: 0.3)
        var engine = TuningEngine(configuration: TunerConfiguration(tuning: tuning))
        var lines: [String] = []
        var readings: [TunerReading] = []
        for (index, chunk) in signal.chunked(1_024).enumerated() {
            guard let frame = engine.process(chunk, sampleRate: c.rate) else { continue }
            var line = String(format: "%d L%.9f G%d", index, frame.level, frame.isSignalPresent ? 1 : 0)
            if let r = frame.reading {
                if !r.isHeld { readings.append(r) }
                line += String(format: " F%.9f C%.9f S%d Q%.9f T%d H%d", r.frequency, r.cents, r.stringIndex, r.clarity, r.isInTune ? 1 : 0, r.isHeld ? 1 : 0)
            }
            lines.append(line)
        }
        return ("## \(c.name)\n" + lines.joined(separator: "\n"), readings)
    }

    @Test("Every frame of every reference signal matches the frozen measurement, and is accurate")
    func golden() throws {
        let rendered = Self.cases.map { ($0, Self.render($0)) }
        try accuracyEnvelope(rendered)
        let current = rendered.map(\.1.text).joined(separator: "\n") + "\n"
        if ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1" {
            try current.write(to: Self.file, atomically: true, encoding: .utf8)
            return
        }
        let frozen = try String(contentsOf: Self.file, encoding: .utf8)
        guard current != frozen else { return }
        // Point at the first differing case and frame.
        let old = frozen.components(separatedBy: "\n"), new = current.components(separatedBy: "\n")
        var header = ""
        for index in 0..<max(old.count, new.count) {
            let a = index < old.count ? old[index] : "<missing>", b = index < new.count ? new[index] : "<missing>"
            if a.hasPrefix("## ") { header = a }
            if a != b {
                Issue.record("measurement changed in \(header)\n  was: \(a)\n  now: \(b)")
                return
            }
        }
    }

    /// Independent of the frozen file: what any version of the engine must achieve on these signals.
    /// The settled part of each note (after the first third) must be on the right string, with a
    /// median error of at most 2 cents per note and 0.5 cent overall.
    private func accuracyEnvelope(_ rendered: [(Case, (text: String, readings: [TunerReading]))]) throws {
        var medians: [Double] = []
        for (c, output) in rendered {
            let settled = Array(output.readings.dropFirst(output.readings.count / 3))
            try #require(!settled.isEmpty, "\(c.name): no settled readings")
            #expect(settled.allSatisfy { $0.stringIndex == c.string }, "\(c.name): wrong string")
            let errors = settled.map { $0.cents - c.cents }.sorted()
            let median = errors[errors.count / 2]
            medians.append(abs(median))
            #expect(abs(median) <= 2, "\(c.name): median error \(median) cents")
        }
        let overall = medians.sorted()[medians.count / 2]
        #expect(overall <= 0.5, "overall median error \(overall) cents")
    }
}
