import Foundation
import AVFoundation
import Combine
import CoreAudio
import AudioToolbox
import AudioUnit

final class AudioEngineManager: ObservableObject {
    @Published var latestEstimate: TuningEstimate? = nil
    @Published var isRunning: Bool = false
    @Published var inputAvailable: Bool = true
    @Published var isInTune: Bool = false
    @Published var referenceA: Double = 440.0
    @Published var availableInputDevices: [AudioInputDevice] = []
    @Published var selectedInputUID: String? = nil
    @Published var isSignalWeak: Bool = false
    @Published var currentInputName: String = ""

    enum Mode: Equatable { case auto, manual(Int) } // index into preset strings
    @Published var mode: Mode = .auto
    @Published var preset: TuningPreset = DefaultTuningPresets.first! // default Standard
    @Published var availablePresets: [TuningPreset] = DefaultTuningPresets

    private let engine = AVAudioEngine()
    private var detector: PitchDetector?
    private var tapInstalled: Bool = false

    private var sampleBuffer: [Float] = []
    private let analysisWindow: Int = 2048
    private var smoothedCents: Double = 0
    private let smoothingBase: Double = 0.25
    private let smoothingMax: Double = 0.7
    private var stableCount: Int = 0
    private let stableThreshold: Int = 6
    private let noiseGateRMS: Double = 0.004

    struct AudioInputDevice: Identifiable, Equatable {
        let id: String      // UID
        let name: String
        let deviceID: AudioDeviceID
    }

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

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
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
                // Update current input name according to selection or system default
                if let sel = self.selectedInputUID, let match = self.availableInputDevices.first(where: { $0.id == sel }) {
                    self.currentInputName = match.name
                } else if let def = self.defaultInputDeviceID() {
                    if let match = self.availableInputDevices.first(where: { $0.deviceID == def }) {
                        self.currentInputName = match.name
                    } else if let name = self.deviceName(for: def) {
                        self.currentInputName = name
                    } else {
                        self.currentInputName = ""
                    }
                }
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
        DispatchQueue.main.async { self.isSignalWeak = (rms < self.noiseGateRMS) }
        if rms < noiseGateRMS { return }

        do {
            let forcedIndex: Int? = {
                switch mode {
                case .auto: return nil
                case .manual(let idx): return idx
                }
            }()
            if let estimate = estimatePresetTuning(samples: window, sampleRate: detector.sampleRate, referenceA: referenceA, preset: preset, forcedIndex: forcedIndex) {
                // Outlier rejection
                if estimate.clarity < 0.2 || abs(estimate.cents) > 300 { return }
                // Smoothing on cents (clarity-adaptive)
                let alpha = smoothingBase + (smoothingMax - smoothingBase) * max(0.0, min(1.0, estimate.clarity))
                if latestEstimate == nil || abs(estimate.cents - smoothedCents) > 80 {
                    smoothedCents = estimate.cents
                } else {
                    smoothedCents = alpha * estimate.cents + (1 - alpha) * smoothedCents
                }

                let smoothEstimate = TuningEstimate(
                    frequency: estimate.frequency,
                    clarity: estimate.clarity,
                    stringLabel: estimate.stringLabel,
                    cents: smoothedCents,
                    stringIndex: estimate.stringIndex
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

    // MARK: - Input Device Handling (macOS)

    func refreshInputDevices() {
        var devices: [AudioInputDevice] = []
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { DispatchQueue.main.async { self.availableInputDevices = [] }; return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &deviceIDs)
        if status != noErr { DispatchQueue.main.async { self.availableInputDevices = [] }; return }

        for dev in deviceIDs {
            // Check if device has input streams
            var streamsAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamsSize: UInt32 = 0
            var hasInput = false
            if AudioObjectGetPropertyDataSize(dev, &streamsAddr, 0, nil, &streamsSize) == noErr, streamsSize >= MemoryLayout<AudioStreamID>.size {
                let count = Int(streamsSize) / MemoryLayout<AudioStreamID>.size
                hasInput = count > 0
            }
            if !hasInput { continue }

            // Name
            let name = getCFStringProperty(dev, kAudioObjectPropertyName) ?? ""

            // UID
            if let uid = getCFStringProperty(dev, kAudioDevicePropertyDeviceUID) {
                devices.append(AudioInputDevice(id: uid, name: name, deviceID: dev))
            }
        }

        // Sort by name for stable UI
        devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        DispatchQueue.main.async {
            self.availableInputDevices = devices
            if let sel = self.selectedInputUID, devices.contains(where: { $0.id == sel }) == false {
                self.selectedInputUID = nil
            }
            // Update current input name (selected or system default)
            if let sel = self.selectedInputUID, let match = devices.first(where: { $0.id == sel }) {
                self.currentInputName = match.name
            } else if let def = self.defaultInputDeviceID(), let match = devices.first(where: { $0.deviceID == def }) {
                self.currentInputName = match.name
            } else {
                self.currentInputName = ""
            }
        }
    }

    func setPreferredInputDevice(uid: String) {
        guard let dev = availableInputDevices.first(where: { $0.id == uid }) else { return }
        selectedInputUID = uid
        currentInputName = dev.name

        let wasRunning = isRunning
        stop()
        setCurrentDeviceID(dev.deviceID)
        if wasRunning { start() }
    }

    func setSystemDefaultInputDevice() {
        let wasRunning = isRunning
        stop()
        if let def = defaultInputDeviceID() {
            setCurrentDeviceID(def)
        }
        selectedInputUID = nil
        if let def = defaultInputDeviceID() {
            if let match = availableInputDevices.first(where: { $0.deviceID == def }) {
                currentInputName = match.name
            } else if let name = deviceName(for: def) {
                currentInputName = name
            } else {
                currentInputName = ""
            }
        } else {
            currentInputName = ""
        }
        if wasRunning { start() }
    }

    private func setCurrentDeviceID(_ deviceID: AudioDeviceID) {
        if let au: AudioUnit = engine.inputNode.audioUnit {
            var dev = deviceID
            _ = AudioUnitSetProperty(
                au,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &dev,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return status == noErr ? dev : nil
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String? {
        return getCFStringProperty(deviceID, kAudioObjectPropertyName)
    }

    private func getCFStringProperty(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status: OSStatus = withUnsafeMutableBytes(of: &value) { rawBuf in
            guard let base = rawBuf.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, base)
        }
        if status == noErr { return value as String }
        return nil
    }
}
