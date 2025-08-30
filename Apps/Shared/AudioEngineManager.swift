import Foundation
import AVFoundation
import Combine
import ChitarraTuneCore

final class AudioEngineManager: ObservableObject {
    @Published var latestEstimate: TuningEstimate? = nil
    @Published var isRunning: Bool = false
    @Published var inputAvailable: Bool = true

    private let engine = AVAudioEngine()
    private var detector: PitchDetector?
    private var cancellables: Set<AnyCancellable> = []

    private var sampleBuffer: [Float] = []
    private let analysisWindow: Int = 4096

    func start() {
#if os(tvOS)
        // tvOS non ha input microfono accessibile alle app
        inputAvailable = false
        isRunning = false
        return
#else
        do {
#if os(iOS)
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.record, mode: .measurement, options: [])
                try session.setActive(true, options: [])
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.inputAvailable = false
                }
                return
            }
#endif
            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            let sr = Double(format.sampleRate)
            detector = PitchDetector(sampleRate: sr)

            sampleBuffer.removeAll(keepingCapacity: true)

            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                guard let channelData = buffer.floatChannelData else { return }
                let frameLength = Int(buffer.frameLength)
                // Prendi canale 0
                let ptr = channelData[0]
                let samples = Array(UnsafeBufferPointer(start: ptr, count: frameLength))
                self.append(samples: samples, sampleRate: sr)
            }

            try engine.start()
            DispatchQueue.main.async {
                self.isRunning = true
                self.inputAvailable = true
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.inputAvailable = false
            }
        }
#endif
    }

    func stop() {
#if !os(tvOS)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
#endif
#endif
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    private func append(samples: [Float], sampleRate: Double) {
        sampleBuffer.append(contentsOf: samples)
        // Mantieni un buffer scorrevole di dimensione massima ~2 finestre
        let maxKeep = analysisWindow * 2
        if sampleBuffer.count > maxKeep {
            sampleBuffer.removeFirst(sampleBuffer.count - maxKeep)
        }

        guard sampleBuffer.count >= analysisWindow, let detector = detector else { return }
        let startIndex = sampleBuffer.count - analysisWindow
        let window = Array(sampleBuffer[startIndex..<sampleBuffer.count])

        if let pitch = detector.estimateFrequency(samples: window) {
            let nearest = nearestGuitarString(for: pitch.frequency)
            let estimate = TuningEstimate(
                frequency: pitch.frequency,
                clarity: pitch.clarity,
                nearestString: nearest.string,
                cents: nearest.cents
            )
            DispatchQueue.main.async {
                self.latestEstimate = estimate
            }
        }
    }
}

