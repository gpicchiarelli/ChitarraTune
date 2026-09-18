import Foundation
import Testing
@testable import TunerCore

@Suite("CrossCorrelator")
struct CrossCorrelatorTests {
    /// Straightforward O(W·lags) reference implementation.
    private func direct(_ a: [Float], _ b: [Float], lags: Int) -> [Double] {
        (0..<lags).map { lag in
            var sum = 0.0
            for j in 0..<a.count where j + lag < b.count { sum += Double(a[j]) * Double(b[j + lag]) }
            return sum
        }
    }

    @Test("Matches the direct computation", arguments: [(600, 900), (1_000, 1_500), (1_846, 2_770)])
    func matchesDirect(window: Int, length: Int) throws {
        let b = SignalGenerator.noise(count: length, amplitude: 0.5, seed: UInt64(window))
        let a = Array(b[0..<window])
        let correlator = try #require(CrossCorrelator(minimumSize: length))
        var fast = [Double](repeating: 0, count: 400)
        correlator.correlate(a, b, lagCount: 400, into: &fast)
        let reference = direct(a, b, lags: 400)
        for lag in 0..<400 {
            #expect(abs(fast[lag] - reference[lag]) < 1e-2 + abs(reference[lag]) * 1e-4, "lag \(lag): \(fast[lag]) vs \(reference[lag])")
        }
    }

    @Test("Transform length is the next power of two")
    func sizes() throws {
        #expect(try #require(CrossCorrelator(minimumSize: 16)).size == 16)
        #expect(try #require(CrossCorrelator(minimumSize: 17)).size == 32)
        #expect(try #require(CrossCorrelator(minimumSize: 2_770)).size == 4_096)
        #expect(CrossCorrelator(minimumSize: 8) == nil)
    }
}
