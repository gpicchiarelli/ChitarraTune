import Foundation
import Testing
@testable import TunerCore

@Suite("Real-time budget")
struct RealTimeBudgetTests {
    /// The share of one core the whole engine may take in an optimised build. Quoted by
    /// `docs/ACCURACY.md` and by `TuningEngine`, and checked against them by `DocumentationSpecTests`.
    static let ceiling = 0.03

    /// The whole engine (six string filters, detector, refinement) on ten seconds of a plucked string,
    /// fed in 1 024-sample callbacks, must cost a small fraction of the audio's duration: the tuner
    /// runs for minutes on a phone.
    ///
    /// The cost is the *fastest* of several passes, and the callbacks are cut before the clock starts.
    /// A shared CI runner preempts the process at moments nobody controls, and preemption only ever
    /// adds time, so the fastest pass is the closest estimate of what the engine itself costs: one
    /// pass measured 1.6 % and 3.1 % of real time on the same runner for identical engine code.
    @Test("Analysing audio takes a small fraction of real time")
    func fractionOfRealTime() throws {
        let rate = 48_000.0
        let seconds = 10.0
        let pluck = StringModel().pluck(frequency: 110, sampleRate: rate, duration: 2)
        let signal = Array(repeating: pluck, count: Int(seconds / 2)).flatMap { $0 }
        let callbacks = signal.chunked(1_024)
        // Unoptimised debug builds are ~60× slower, assert nothing, and would spend a minute here. One
        // pass of them says little: the same build measured 56 % and 205 % of real time on one machine.
        // ADR 0018 rule 5: the budgets keep a CI job of their own, on an unloaded runner, "because a
        // timing assertion measured beside a saturated test suite measures the suite". That was a
        // sentence in a record and not a line of code, so this also ran in the pre-push hook — after
        // SwiftLint, two linters and a full optimised build — and refused a push. Measured there
        // under load the five passes were 0.83, 2.19, 2.45, 2.52 and 2.58 % against a 3 % ceiling: it
        // passed on the one pass that caught a quiet moment. It runs and prints everywhere; it holds
        // the ceiling only where the ceiling means something.
        let enforced = ProcessInfo.processInfo.environment["CHITARRA_FULL_DSP"] == "1"
        #if DEBUG
        let (attempts, caveat) = (1, " — one unoptimised pass, indicative only")
        #else
        let (attempts, caveat) = (5, enforced ? "" : " — ceiling not enforced outside the DSP job")
        #endif
        let passes = (1...attempts).map { _ in
            var engine = TuningEngine()
            return ContinuousClock().measure {
                for callback in callbacks { _ = engine.process(callback, sampleRate: rate) }
            }
        }
        let fastest = try #require(passes.min())
        let fraction = fastest / .seconds(seconds)
        let percentages = passes.map {
            ($0 / .seconds(seconds) * 100).formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX")))
        }
        print("engine: \(fastest) for \(seconds) s of audio (\(fraction * 100) % of real time); "
            + "passes \(percentages) %\(caveat)")
        // What is promised is the ceiling, not the measurement: a measurement is hardware (0.6 % on an
        // M-series Mac, 1.6 % on a shared CI runner, and it moves with both the machine and the
        // toolchain), while a ceiling is a decision, and it is the only number the documents may quote.
        // `DocumentationSpecTests` holds them to this line. The optimised build runs in the "DSP
        // accuracy" CI job; the room is for slower hardware, not for a regression.
        #if !DEBUG
        if enforced { #expect(fraction < Self.ceiling) }
        #endif
    }
}
