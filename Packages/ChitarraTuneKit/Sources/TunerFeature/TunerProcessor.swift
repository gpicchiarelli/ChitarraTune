import Foundation
import os
import TunerAudio
import TunerCore

/// Runs the DSP off the main actor. It owns the (non-`Sendable`) ``TuningEngine``, so all access
/// is serialised by actor isolation and no locks or `@unchecked Sendable` are needed.
actor TunerProcessor {
    private var engine = TuningEngine()
    private var parameters = EngineParameters.standard
    private let signposter = OSSignposter(subsystem: "com.chitarratune.app", category: .pointsOfInterest)

    func process(
        _ chunk: AudioChunk,
        configuration: TunerConfiguration,
        parameters: EngineParameters
    ) -> TunerFrame? {
        if parameters != self.parameters {
            self.parameters = parameters
            engine = TuningEngine(configuration: configuration, parameters: parameters)
        }
        engine.reconfigure(configuration)

        let interval = signposter.beginInterval("analyse")
        defer { signposter.endInterval("analyse", interval) }
        return engine.process(chunk.samples, sampleRate: chunk.sampleRate)
    }
}
