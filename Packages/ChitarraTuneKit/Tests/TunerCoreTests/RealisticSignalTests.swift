import Foundation
import Testing
@testable import TunerCore

/// Accuracy on signals that behave like a real guitar (see ``StringModel``): inharmonic partials,
/// a microphone that loses the low end, pick noise, room noise and hum.
///
/// The numbers checked here are the ones a player sees: the reading must name the right string,
/// never jump an octave, and stay within a fraction of the ±5 cent in-tune window.
@Suite("Realistic signals")
struct RealisticSignalTests {
    struct Scenario: CustomTestStringConvertible, Sendable {
        let name: String
        let sampleRate: Double
        let model: StringModel
        /// Limits on the deviation the player sees (smoothed cents), over every string of every
        /// tuning and several detunings: the typical error (median) and the worst settled frame.
        let typical: Double
        let worst: Double
        var testDescription: String { name }
    }

    /// The in-tune window is ±5 cents. The first three scenarios are the everyday ones and are held
    /// to a fraction of it; the last two are deliberately hostile and document the current limits.
    static let scenarios: [Scenario] = [
        Scenario(name: "pickup into an interface, 48 kHz", sampleRate: 48_000, model: StringModel(),
                 typical: 1, worst: 5),
        Scenario(name: "plucked over the soundhole, stiff strings", sampleRate: 48_000,
                 model: StringModel(inharmonicity: 3e-4, pluckPosition: 0.33), typical: 1, worst: 7),
        Scenario(name: "acoustic in front of a phone, 48 kHz", sampleRate: 48_000,
                 model: StringModel(microphone: .phone(cutoff: 160), roomNoise: 0.004), typical: 1, worst: 6),
        Scenario(name: "phone in a noisy room, 44.1 kHz", sampleRate: 44_100,
                 model: StringModel(microphone: .phone(cutoff: 220), roomNoise: 0.008, hum: 0.006), typical: 1.5, worst: 11),
        Scenario(name: "quiet pluck close to the bridge", sampleRate: 44_100,
                 model: StringModel(pluckPosition: 0.08, amplitude: 0.05), typical: 3, worst: 12),
    ]

    /// Settled readings (after the attack) for one pluck.
    private func readings(
        _ model: StringModel,
        tuning: Tuning,
        frequency: Double,
        sampleRate: Double,
        target: StringTarget = .automatic,
        parameters: EngineParameters = .standard
    ) -> [TunerReading] {
        var engine = TuningEngine(configuration: .init(tuning: tuning, target: target), parameters: parameters)
        let signal = model.pluck(frequency: frequency, sampleRate: sampleRate, duration: 1.0)
        var result: [TunerReading] = []
        var elapsed = 0
        for chunk in signal.chunked(1_024) {
            elapsed += chunk.count
            if let reading = engine.process(chunk, sampleRate: sampleRate)?.reading,
               !reading.isHeld, Double(elapsed) / sampleRate > 0.35 {
                result.append(reading)
            }
        }
        return result
    }

    /// Every tuning and string in tune, plus flat and sharp plucks on Standard and Drop C. Set
    /// `CHITARRA_FULL_DSP=1` for the full matrix (every tuning × string × detuning); CI runs it
    /// in an optimised build.
    static func cases() -> [(tuning: Tuning, offset: Double)] {
        let full = ProcessInfo.processInfo.environment["CHITARRA_FULL_DSP"] == "1"
        return Tuning.catalog.flatMap { tuning -> [(tuning: Tuning, offset: Double)] in
            let offsets = full || tuning.id == .standard ? [-35.0, 0.0, 22.0] : [0.0]
            return offsets.map { (tuning, $0) }
        }
    }

    @Test("Every string of every tuning is named and measured accurately", arguments: scenarios)
    func everyString(scenario: Scenario) throws {
        var typicalErrors: [Double] = []
        var worstError = 0.0
        for (tuning, offset) in Self.cases() {
            for (index, note) in tuning.strings.enumerated() {
                do {
                    let played = note.frequency() * pow(2, offset / 1200)
                    let label = "\(tuning.id) · string \(index + 1) \(note.label()) \(offset) ¢"
                    let settled = readings(scenario.model, tuning: tuning, frequency: played, sampleRate: scenario.sampleRate)
                    try #require(settled.count >= 10, "too few readings: \(label)")
                    // Right string, and never an octave (or another string) away.
                    #expect(settled.allSatisfy { $0.stringIndex == index }, "wrong string: \(label)")
                    let errors = settled.map { abs($0.cents - offset) }.sorted()
                    typicalErrors.append(errors[errors.count / 2])
                    worstError = max(worstError, errors.last ?? .infinity)
                }
            }
        }
        let typical = typicalErrors.sorted()[typicalErrors.count / 2]
        print("\(scenario.name): typical \(typical) ¢, worst \(worstError) ¢")
        #expect(typical < scenario.typical, "typical error \(typical) ¢")
        #expect(worstError < scenario.worst, "worst error \(worstError) ¢")
    }

    /// Mains hum inside a low string's refinement band beats with the fundamental and pulls the
    /// refined period (see `PartialFilter.humNotches`). Before the hum notches a low D read up to
    /// 10 cents flat at the Low Power analysis rate. Hum here is twice the everyday model's level.
    @Test("Mains hum at 50 or 60 Hz does not bias the low strings, at either analysis rate",
          arguments: [(50.0, 0.025), (50.0, 0.045), (60.0, 0.025), (60.0, 0.045)])
    func mainsHum(mains: Double, hop: Double) throws {
        var model = StringModel(hum: 0.006)
        model.humFrequency = mains
        var parameters = EngineParameters.standard
        parameters.hopDuration = hop
        let lowStrings: [(TuningID, Int)] = [(.dropC, 0), (.dropD, 0), (.halfDown, 0), (.standard, 0), (.dropC, 1), (.halfDown, 1), (.standard, 1)]
        var medians: [Double] = []
        for (id, index) in lowStrings {
            let tuning = Tuning.tuning(for: id)
            for offset in [-23.0, 17.0] {
                let played = tuning.strings[index].frequency() * pow(2, offset / 1200)
                let settled = readings(model, tuning: tuning, frequency: played, sampleRate: 48_000, parameters: parameters)
                try #require(settled.count >= 5, "too few readings: \(id) string \(index + 1)")
                #expect(settled.allSatisfy { $0.stringIndex == index }, "wrong string: \(id) string \(index + 1)")
                let errors = settled.map { abs($0.cents - offset) }.sorted()
                medians.append(errors[errors.count / 2])
                #expect(errors[errors.count / 2] < 2.5, "\(id) string \(index + 1) \(offset) ¢ with \(mains) Hz hum: \(errors[errors.count / 2]) ¢")
            }
        }
        let typical = medians.sorted()[medians.count / 2]
        print("mains \(mains) Hz, hop \(hop) s: typical \(typical) ¢, worst note \(medians.max() ?? 0) ¢")
        #expect(typical < 0.8)
    }

    /// The string filters ring after every attack, their hum notches for about a hundred milliseconds.
    /// A correction measured on that ringing used to read a perfect tone 1.6 cents sharp 0.3 s after
    /// it started, and took a second to recover.
    @Test("The refinement never measures the filters' own ringing after an attack", arguments: [36, 38, 40, 43, 45])
    func noRingingAfterAttack(midi: Int) throws {
        let tuning = Tuning(id: .standard, strings: [Note(midi: midi)])
        let frequency = Note(midi: midi).frequency()
        let signal = SignalGenerator.tone(frequency: frequency, sampleRate: 44_100, duration: 1, harmonics: SignalGenerator.guitarHarmonics, amplitude: 0.3)
        var engine = TuningEngine(configuration: .init(tuning: tuning))
        var elapsed = 0
        for chunk in signal.chunked(1_024) {
            elapsed += chunk.count
            guard let reading = engine.process(chunk, sampleRate: 44_100)?.reading, Double(elapsed) / 44_100 > 0.25 else { continue }
            #expect(abs(reading.cents) < 0.05, "\(Note(midi: midi).label()) at \(Double(elapsed) / 44_100) s: \(reading.cents) ¢")
        }
    }

    @Test("A pinned string reads the fundamental even when the second harmonic dominates")
    func pinnedLowString() throws {
        // Low E through a phone: the 82 Hz fundamental is about a fifth as loud as the 165 Hz octave.
        let model = StringModel(microphone: .phone(cutoff: 220))
        let target = Note(midi: 40).frequency()
        let settled = readings(model, tuning: .standard, frequency: target, sampleRate: 48_000, target: .string(0))
        try #require(!settled.isEmpty)
        for reading in settled {
            #expect(abs(reading.cents) < 3, "\(reading.cents) ¢")
        }
    }

    @Test("A string in tune is declared in tune, and one 20 cents off is not")
    func inTuneVerdict() throws {
        let model = StringModel(microphone: .phone(cutoff: 160), roomNoise: 0.004)
        for (index, note) in Tuning.standard.strings.enumerated() {
            let good = readings(model, tuning: .standard, frequency: note.frequency(), sampleRate: 48_000)
            #expect(good.last?.isInTune == true, "string \(index + 1) in tune")
            let bad = readings(model, tuning: .standard, frequency: note.frequency() * pow(2, 20.0 / 1200), sampleRate: 48_000)
            #expect(bad.contains { $0.isInTune } == false, "string \(index + 1) 20 ¢ sharp")
        }
    }

    @Test("Room noise alone never produces a reading")
    func noiseOnly() {
        let model = StringModel(hum: 0.003, amplitude: 0)
        let settled = readings(model, tuning: .standard, frequency: 110, sampleRate: 48_000)
        #expect(settled.isEmpty)
    }
}
