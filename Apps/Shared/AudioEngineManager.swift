import Foundation
import AVFoundation
import Combine

final class AudioEngineManager: ObservableObject {
    @Published var latestEstimate: TuningEstimate? = nil
    @Published var isRunning: Bool = false
    @Published var inputAvailable: Bool = true
    @Published var isInTune: Bool = false
    @Published var referenceA: Double = 440.0

    enum Mode: Equatable { case auto, manual(GuitarString) }
    @Published var mode: Mode = .auto

    private let engine = AVAudioEngine()
    private var detector: PitchDetector?
    private var tapInstalled: Bool = false

    private var sampleBuffer: [Float] = []
    private let analysisWindow: Int = 4096
    private var smoothedCents: Double = 0
    private let smoothingAlpha: Double = 0.25
    private var stableCount: Int = 0
    private let stableThreshold: Int = 6
    private let noiseGateRMS: Double = 0.005

    func start() {
        // Avoid re-installing tap / restarting if already running
        if isRunning || tapInstalled { return }
        // Check permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            self.inputAvailable = false
            self.isRunning = false
            return
        }

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { self.start() } else { self.inputAvailable = false; self.isRunning = false }
                }
            }
            return
        }

        do {
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
            tapInstalled = true

            try engine.start()
            DispatchQueue.main.async {
                self.isRunning = true
                self.inputAvailable = true
            }
        } catch {
            // If engine failed to start and a tap was installed, remove it safely
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.inputAvailable = false
            }
        }
    }

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
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

        // Noise gate by RMS
        var sumSq: Double = 0
        for s in window { let d = Double(s); sumSq += d * d }
        let rms = sqrt(sumSq / Double(window.count))
        if rms < noiseGateRMS { return }

        if let pitch = detector.estimateFrequency(samples: window) {
            let forced: GuitarString? = {
                switch mode {
                case .auto: return nil
                case .manual(let s): return s
                }
            }()
            if let estimate = estimateGuitarTuning(samples: window, sampleRate: detector.sampleRate, referenceA: referenceA, forcedString: forced) {
                // Smoothing on cents
                if latestEstimate == nil { smoothedCents = estimate.cents }
                smoothedCents = smoothingAlpha * estimate.cents + (1 - smoothingAlpha) * smoothedCents

                let smoothEstimate = TuningEstimate(
                    frequency: estimate.frequency,
                    clarity: estimate.clarity,
                    nearestString: estimate.nearestString,
                    cents: smoothedCents
                )

                // Stability detection
                if abs(smoothedCents) < 5 {
                    stableCount = min(stableThreshold, stableCount + 1)
                } else {
                    stableCount = 0
                }

                DispatchQueue.main.async {
                    self.latestEstimate = smoothEstimate
                    self.isInTune = (self.stableCount >= self.stableThreshold)
                }
            }
        }
    }
}
