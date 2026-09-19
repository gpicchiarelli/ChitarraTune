import Foundation
import Testing
@testable import TunerCore

/// Pins the numbers that README.md and docs/ARCHITECTURE.md promise, so code and documentation cannot
/// drift apart silently. If one of these fails, change the code *and* the document on purpose.
@Suite("Documented behaviour · TunerCore")
struct SpecConformanceTests {
    @Test("Engine parameters match docs/ARCHITECTURE.md")
    func engineParameters() {
        let p = EngineParameters.standard
        #expect(p.hopDuration == 0.025)          // "one analysis every 25 ms"
        #expect(p.gateOpenLevel == 0.004)        // "noise gate opens at 0.004 RMS"
        #expect(p.gateCloseLevel == 0.0025)      // "…and closes at 0.0025"
        #expect(p.minimumGateLevel == 0.0006)    // "down to 0.0006 RMS"
        #expect(p.gateNoiseMargin == 4)          // "4× above the measured noise floor"
        #expect(p.noiseFloorRise == 3)           // "rises at most 3 dB per second"
        #expect(p.minimumClarity == 0.55)        // "minimum clarity 0.55"
        #expect(p.maximumDeviation == 300)       // "deviations beyond ±300 cents are ignored"
        #expect(p.inTuneThreshold == 5)          // "in tune is ±5 cents"
        #expect(p.inTuneExitMargin == 2)         // "with 2 cents of exit margin"
        #expect(p.stableHopsRequired == 6)       // "six consecutive stable analyses"
        #expect(p.holdDuration == 0.8)           // "held for 0.8 s after the signal fades"
    }

    @Test("Supported A4 range is 415–466 Hz")
    func referenceRange() {
        #expect(PitchMath.referenceARange == 415...466)
        #expect(PitchMath.standardReferenceA == 440)
    }

    @Test("There are ten tunings, each with six strings, in the documented order")
    func catalogShape() {
        #expect(Tuning.catalog.count == 10)
        #expect(Tuning.catalog.map(\.id) == [.standard, .halfDown, .fullDown, .dropD, .dropC, .dadgad, .openD, .openG, .openE, .openA])
        #expect(Tuning.catalog.allSatisfy { $0.stringCount == 6 })
    }

    @Test("Strings of every tuning are ordered from low to high pitch")
    func stringsAscend() {
        for tuning in Tuning.catalog {
            #expect(tuning.strings == tuning.strings.sorted(), "\(tuning.id) is not low → high")
        }
    }

    @Test("Detection range reaches the lowest string of every tuning at every supported A4", arguments: [415.0, 440.0, 466.0])
    func lowestStringIsAudible(referenceA: Double) throws {
        for tuning in Tuning.catalog {
            let lowest = try #require(tuning.strings.map { $0.frequency(referenceA: referenceA) }.min())
            #expect(tuning.detectionRange(referenceA: referenceA).contains(lowest), "\(tuning.id) @ \(referenceA)")
        }
    }

    @Test("Every string of every tuning is recognised automatically at every supported A4", arguments: [415.0, 440.0, 466.0])
    func everyStringEverywhere(referenceA: Double) {
        for tuning in Tuning.catalog {
            for (index, note) in tuning.strings.enumerated() {
                let match = tuning.nearestString(to: note.frequency(referenceA: referenceA), referenceA: referenceA)
                #expect(match.index == index && abs(match.cents) < 0.001, "\(tuning.id) string \(index) @ \(referenceA)")
            }
        }
    }

    @Test("Fixed-do solfège and English names agree with the notation the README describes")
    func notationNames() {
        let natural = NoteLetter.allCases
        #expect(natural.map(\.english) == ["C", "D", "E", "F", "G", "A", "B"])
        #expect(natural.map(\.solfege) == ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"])
    }
}
