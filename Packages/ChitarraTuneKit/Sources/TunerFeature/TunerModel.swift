import Foundation
import Observation
import os
import TunerAudio
import TunerCore

/// Presentation model of one tuner window: owns capture, feeds the DSP and exposes the state the
/// UI renders. All mutation happens on the main actor; the DSP itself runs in ``TunerProcessor``.
///
/// Power notes: nothing runs while the tuner is idle; there are no timers or polling loops; the
/// UI-facing properties are only written when their value actually changes, so SwiftUI's
/// fine-grained observation redraws the minimum.
@MainActor
@Observable
public final class TunerModel: Identifiable {
    public enum Status: Sendable, Hashable {
        case idle
        case starting
        case listening
        case failed(CaptureFailure)
    }

    private static let logger = Logger(subsystem: "com.chitarratune.app", category: "Tuner")

    public nonisolated let id: UUID
    public let settings: TunerSettings

    // MARK: Per-window configuration

    public var tuning: Tuning {
        didSet {
            guard tuning != oldValue else { return }
            settings.lastTuningID = tuning.id
            if case .string(let index) = target, index >= tuning.stringCount { target = .automatic }
        }
    }

    public var target: StringTarget = .automatic

    public private(set) var inputSelection: AudioInputSelection

    // MARK: Observable output

    public private(set) var status: Status = .idle
    public private(set) var reading: TunerReading?
    /// `true` while the noise gate is open.
    public private(set) var hasSignal = false
    /// Input level for a meter, `0...1` (quantised to limit redraws).
    public private(set) var inputLevel = 0.0
    public private(set) var availableInputs: [AudioInputDevice] = []
    public private(set) var activeInputName: String?
    /// `true` if the last session ended because nothing was played for the idle timeout.
    public private(set) var didStopForInactivity = false
    public private(set) var powerProfile: PowerProfile = .current()

    // MARK: Dependencies & session state

    @ObservationIgnored private let capture: any AudioCapturing
    @ObservationIgnored private let authorization: any MicrophoneAuthorizing
    @ObservationIgnored private let inputs: any AudioInputProviding
    @ObservationIgnored private let now: @Sendable () -> ContinuousClock.Instant
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var restartBudget = 3
    #if os(macOS)
    @ObservationIgnored private var activity: (any NSObjectProtocol)?
    #endif

    public init(
        id: UUID = UUID(),
        settings: TunerSettings,
        capture: any AudioCapturing,
        authorization: any MicrophoneAuthorizing,
        inputs: any AudioInputProviding,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { .now }
    ) {
        self.id = id
        self.settings = settings
        self.capture = capture
        self.authorization = authorization
        self.inputs = inputs
        self.now = now
        self.tuning = Tuning.tuning(for: settings.lastTuningID)
        self.inputSelection = settings.lastInputID.map { .device(id: $0) } ?? .systemDefault
    }

    // MARK: - Derived state

    public var configuration: TunerConfiguration {
        TunerConfiguration(tuning: tuning, referenceA: settings.referenceA, target: target)
    }

    public var isListening: Bool { status == .listening }
    public var isBusy: Bool { status == .starting || status == .listening }

    public var failure: CaptureFailure? {
        if case .failed(let failure) = status { failure } else { nil }
    }

    /// Index of the string to highlight: the pinned one, or the detected one in automatic mode.
    public var highlightedString: Int? {
        switch target {
        case .string(let index): index
        case .automatic: reading?.stringIndex
        }
    }

    // MARK: - Session control

    public func toggle() async {
        if isBusy { await stop() } else { await start() }
    }

    public func start() async {
        guard !isBusy else { return }
        status = .starting
        didStopForInactivity = false
        generation += 1
        let mine = generation

        switch authorization.status() {
        case .authorized:
            break
        case .notDetermined:
            guard await authorization.request() else { return fail(.microphoneDenied, generation: mine) }
        case .denied:
            return fail(.microphoneDenied, generation: mine)
        case .restricted:
            return fail(.microphoneRestricted, generation: mine)
        }
        guard mine == generation else { return } // stopped while the permission prompt was up

        do {
            let stream = try await capture.start(input: inputSelection)
            guard mine == generation else {
                await capture.stop()
                return
            }
            begin(stream, generation: mine)
        } catch {
            fail(error, generation: mine)
        }
    }

    public func stop() async {
        generation += 1
        sessionTask?.cancel()
        sessionTask = nil
        endActivity()
        await capture.stop()
        clearOutput()
        status = .idle
    }

    private func begin(_ stream: AsyncThrowingStream<AudioChunk, any Error>, generation mine: Int) {
        status = .listening
        restartBudget = 3
        beginActivity()
        refreshInputs()
        Self.logger.info("listening")
        sessionTask = Task(priority: .userInitiated) { [weak self] in
            await self?.consume(stream, generation: mine)
        }
    }

    private func fail(_ failure: CaptureFailure, generation mine: Int) {
        guard mine == generation else { return }
        Self.logger.error("failed: \(String(describing: failure), privacy: .public)")
        endActivity()
        clearOutput()
        status = .failed(failure)
    }

    private func fail(_ error: any Error, generation mine: Int) {
        fail(CaptureFailure(error), generation: mine)
    }

    private func clearOutput() {
        reading = nil
        hasSignal = false
        inputLevel = 0
    }

    // MARK: - Consuming audio

    private func consume(_ stream: AsyncThrowingStream<AudioChunk, any Error>, generation mine: Int) async {
        let processor = TunerProcessor()
        var lastSignal = now()
        do {
            for try await chunk in stream {
                guard mine == generation else { return }
                let frame = await processor.process(
                    chunk,
                    configuration: configuration,
                    parameters: powerProfile.engineParameters
                )
                guard mine == generation, let frame else { continue }
                apply(frame)

                if frame.isSignalPresent {
                    lastSignal = now()
                    restartBudget = 3
                } else if let limit = settings.idleTimeout.seconds, now() - lastSignal > .seconds(limit) {
                    Self.logger.info("stopping after \(limit, format: .fixed(precision: 0)) s of silence")
                    await stop()
                    didStopForInactivity = true
                    return
                }
            }
            if mine == generation { await stop() }
        } catch {
            guard mine == generation else { return }
            await recover(from: CaptureFailure(error), generation: mine)
        }
    }

    private func apply(_ frame: TunerFrame) {
        if reading != frame.reading { reading = frame.reading }
        if hasSignal != frame.isSignalPresent { hasSignal = frame.isSignalPresent }
        let level = Self.meterLevel(rms: frame.level)
        if level != inputLevel { inputLevel = level }
    }

    /// Maps RMS (−70 dBFS … −6 dBFS) onto `0…1` in 1/32 steps.
    nonisolated static func meterLevel(rms: Double) -> Double {
        let decibels = 20 * log10(max(rms, 1e-7))
        let unit = min(1, max(0, (decibels + 70) / 64))
        return (unit * 32).rounded() / 32
    }

    private func recover(from failure: CaptureFailure, generation mine: Int) async {
        await capture.stop()
        guard mine == generation else { return }
        if failure == .configurationChanged, restartBudget > 0 {
            restartBudget -= 1
            Self.logger.info("audio route changed; restarting (\(self.restartBudget) left)")
            let remaining = restartBudget
            status = .idle
            await start()
            restartBudget = remaining
        } else {
            fail(failure, generation: mine)
        }
    }

    // MARK: - String selection

    public func pinString(_ index: Int) {
        guard tuning.strings.indices.contains(index) else { return }
        target = .string(index)
    }

    public func releaseString() { target = .automatic }

    // MARK: - Inputs & environment

    public func refreshInputs() {
        availableInputs = inputs.availableInputs()
        activeInputName = inputs.activeInputName(for: inputSelection)
    }

    public func selectInput(_ selection: AudioInputSelection) async {
        guard selection != inputSelection else { return }
        inputSelection = selection
        settings.lastInputID = selection.deviceID
        refreshInputs()
        if isBusy {
            await stop()
            await start()
        }
    }

    /// Long-running observation of input hot-plugging and the device power state. Attach it with
    /// `.task { await model.monitorEnvironment() }`; structured concurrency cancels it (and with it
    /// every listener) when the view goes away.
    public func monitorEnvironment() async {
        await reconcileSelectedInput()
        let inputChanges = inputs.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inputChanges { await self?.reconcileSelectedInput() }
            }
            group.addTask { [weak self] in
                for await _ in PowerProfile.changes() { await self?.updatePowerProfile() }
            }
        }
    }

    private func reconcileSelectedInput() async {
        refreshInputs()
        if let id = inputSelection.deviceID, !availableInputs.contains(where: { $0.id == id }) {
            Self.logger.info("selected input disappeared; using system default")
            await selectInput(.systemDefault)
        }
    }

    private func updatePowerProfile() {
        let profile = PowerProfile.current()
        if profile != powerProfile { powerProfile = profile }
    }

    // MARK: - Power assertions (macOS)

    private func beginActivity() {
        #if os(macOS)
        // Keeps App Nap from throttling analysis while the window is covered; the system may still sleep.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Guitar tuning in progress"
        )
        #endif
    }

    private func endActivity() {
        #if os(macOS)
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        #endif
    }
}
