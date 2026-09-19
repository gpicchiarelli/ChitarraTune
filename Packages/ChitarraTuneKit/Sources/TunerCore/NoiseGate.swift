import Foundation

/// Decides whether something is being played, from the signal level, with hysteresis.
///
/// In a noisy room it opens at the fixed ``EngineParameters/gateOpenLevel``. In a quieter one it
/// opens ``EngineParameters/gateNoiseMargin`` above the room's measured noise floor, down to
/// ``EngineParameters/minimumGateLevel``: a quiet source (an unplugged electric, the top strings
/// into a laptop's microphone) is measured without raising the input gain. The noise-floor estimate
/// falls at once to anything quieter, rises at most ``EngineParameters/noiseFloorRise`` dB per second
/// while the gate is closed, and stands still while it is open, so a ringing string is never taken
/// for the room. The engine's clarity test still rejects anything that is not a periodic note.
struct NoiseGate {
    private let parameters: EngineParameters
    private(set) var isOpen = false
    /// Estimated level of the room when nothing is played. Starts where the gate opens at its fixed
    /// level, and learns from the first quiet analyses.
    private(set) var noiseFloor: Double

    init(parameters: EngineParameters) {
        self.parameters = parameters
        noiseFloor = parameters.gateOpenLevel / parameters.gateNoiseMargin
    }

    /// The level the gate opens at now.
    var openLevel: Double {
        min(parameters.gateOpenLevel, max(parameters.minimumGateLevel, noiseFloor * parameters.gateNoiseMargin))
    }

    /// Updates the gate with the level of one analysis, `elapsed` seconds after the previous one.
    mutating func update(level: Double, elapsed: Double) {
        let open = openLevel
        let close = open * parameters.gateCloseLevel / parameters.gateOpenLevel
        isOpen = isOpen ? level > close : level > open
        if !isOpen {
            noiseFloor = min(level, noiseFloor * pow(10, parameters.noiseFloorRise * elapsed / 20))
        }
    }
}
