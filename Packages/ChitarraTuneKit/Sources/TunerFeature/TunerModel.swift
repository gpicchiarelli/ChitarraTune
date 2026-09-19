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

    private static let logger = TunerLog.tuner

    nonisolated public let id: UUID
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
    /// Full-detail reading; changes on every analysis (~40 Hz). Read it only in the few views that
    /// draw the needle and numbers. Everything else should use the coarse summaries below, which are
    /// only written when their value changes.
    public private(set) var reading: TunerReading?
    public private(set) var tuneState: TuneState = .idle
    /// Note of the string currently detected (automatic mode) — changes only when the string changes.
    public private(set) var detectedNote: Note?
    public private(set) var detectedString: Int?
    /// `true` while the noise gate is open.
    public private(set) var hasSignal = false
    /// Input level for a meter, `0...1` (quantised to limit redraws).
    public private(set) var inputLevel = 0.0
    public private(set) var availableInputs: [AudioInputDevice] = []
    public private(set) var activeInputName: String?
    /// `true` if the last session ended because nothing was played for the idle timeout.
    public private(set) var didStopForInactivity = false
    public private(set) var powerProfile: PowerProfile = .standard

    // MARK: Dependencies & session state

    @ObservationIgnored private let capture: any AudioCapturing
    @ObservationIgnored private let authorization: any MicrophoneAuthorizing
    @ObservationIgnored private let inputs: any AudioInputProviding
    @ObservationIgnored private let now: @Sendable () -> ContinuousClock.Instant
    @ObservationIgnored private let power: PowerSource
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    /// How many automatic restarts a route change may still trigger before the failure is shown.
    @ObservationIgnored private var restartBudget = TunerModel.restartLimit
    @ObservationIgnored private var processor: TunerProcessor?
    /// Configuration last handed to ``processor``.
    @ObservationIgnored private var appliedConfiguration: TunerConfiguration?
    @ObservationIgnored private var appliedParameters: EngineParameters?
    @ObservationIgnored private var lastSignal = ContinuousClock.Instant.now
    static let restartLimit = 3
    /// Open while waiting for the first analysed frame (Instruments ▸ Points of Interest).
    @ObservationIgnored private var firstFrameInterval: OSSignpostIntervalState?
    #if os(macOS)
    @ObservationIgnored private var activity: (any NSObjectProtocol)?
    #endif

    public init(
        id: UUID = UUID(),
        settings: TunerSettings,
        capture: any AudioCapturing,
        authorization: any MicrophoneAuthorizing,
        inputs: any AudioInputProviding,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { .now },
        power: PowerSource = .system
    ) {
        self.id = id
        self.settings = settings
        self.capture = capture
        self.authorization = authorization
        self.inputs = inputs
        self.now = now
        self.power = power
        self.powerProfile = power.current()
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

    public var isInTune: Bool { tuneState == .inTune }

    /// `true` until the user has answered the system microphone prompt. The app shows a short
    /// explanation first, so the prompt never arrives out of the blue.
    public var needsMicrophonePermission: Bool { authorization.status() == .notDetermined }

    /// Index of the string to highlight: the pinned one, or the detected one in automatic mode.
    public var highlightedString: Int? {
        switch target {
        case .string(let index): index
        case .automatic: detectedString
        }
    }

    // MARK: - Session control

    public func toggle() async {
        if isBusy { await stop() } else { await start() }
    }

    public func start() async {
        await start(restartBudget: Self.restartLimit)
    }

    /// - Parameter budget: automatic restarts still allowed after a route change. Passed explicitly so
    ///   that a restart cannot refill its own budget.
    private func start(restartBudget budget: Int) async {
        guard !isBusy else { return }
        status = .starting
        didStopForInactivity = false
        generation += 1
        let mine = generation
        Self.logger.notice("start requested; microphone permission: \(String(describing: self.authorization.status()), privacy: .public)")
        firstFrameInterval = TunerLog.signposter.beginInterval("timeToFirstFrame")

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
            begin(stream, generation: mine, restartBudget: budget)
        } catch {
            fail(error, generation: mine)
        }
    }

    public func stop() async {
        Self.logger.notice("stop requested")
        endFirstFrameInterval()
        generation += 1
        sessionTask?.cancel()
        sessionTask = nil
        processor = nil
        endActivity()
        // `status` drops to `.idle` before the hardware teardown finishes (below), not after: a
        // `start()` racing this call must see the tuner as free rather than bail out on `isBusy` while
        // this `stop()` is still awaiting `capture.stop()`. `capture` is an actor, so the two calls
        // still serialize correctly however they interleave.
        clearOutput()
        status = .idle
        await capture.stop()
    }

    private func begin(_ stream: AsyncThrowingStream<AudioChunk, any Error>, generation mine: Int, restartBudget budget: Int) {
        status = .listening
        restartBudget = budget
        lastSignal = now()
        beginActivity()
        refreshInputs()
        Self.logger.info("listening (input: \(String(describing: self.inputSelection), privacy: .private), profile: \(String(describing: self.powerProfile), privacy: .public))")
        let parameters = powerProfile.engineParameters
        let processor = TunerProcessor(configuration: configuration, parameters: parameters)
        self.processor = processor
        appliedConfiguration = configuration
        appliedParameters = parameters
        let frames = processor.frames(from: stream)
        // Only frames cross to the main actor. `self` is re-acquired weakly for each frame, so a closed
        // window's model is not kept alive by its audio stream.
        sessionTask = Task(priority: .userInitiated) { [weak self] in
            do {
                for try await frame in frames {
                    guard let self, await self.receive(frame, generation: mine) else { return }
                }
                await self?.streamEnded(generation: mine)
            } catch {
                await self?.recover(from: CaptureFailure(error), generation: mine)
            }
        }
    }

    private func fail(_ failure: CaptureFailure, generation mine: Int) {
        guard mine == generation else { return }
        Self.logger.error("failed: \(String(describing: failure), privacy: .public)")
        endFirstFrameInterval()
        endActivity()
        clearOutput()
        status = .failed(failure)
    }

    private func clearOutput() {
        reading = nil
        if tuneState != .idle { tuneState = .idle }
        if detectedNote != nil { detectedNote = nil }
        if detectedString != nil { detectedString = nil }
        hasSignal = false
        inputLevel = 0
    }

    // MARK: - Consuming frames

    /// Applies one analysed frame. Returns `false` when the session is over.
    private func receive(_ frame: TunerFrame, generation mine: Int) async -> Bool {
        guard mine == generation else { return false }
        await pushConfigurationIfNeeded()
        apply(frame)
        if frame.isSignalPresent {
            lastSignal = now()
            restartBudget = Self.restartLimit
        } else if let limit = settings.idleTimeout.seconds, now() - lastSignal > .seconds(limit) {
            Self.logger.info("stopping after \(limit, format: .fixed(precision: 0)) s of silence")
            await stop()
            didStopForInactivity = true
            return false
        }
        return true
    }

    /// Hands a changed tuning, A4, target or power profile to the processor (within one analysis hop).
    private func pushConfigurationIfNeeded() async {
        let configuration = configuration, parameters = powerProfile.engineParameters
        guard configuration != appliedConfiguration || parameters != appliedParameters, let processor else { return }
        appliedConfiguration = configuration
        appliedParameters = parameters
        await processor.update(configuration: configuration, parameters: parameters)
    }

    private func streamEnded(generation mine: Int) async {
        if mine == generation { await stop() }
    }

    private func endFirstFrameInterval() {
        guard let interval = firstFrameInterval else { return }
        TunerLog.signposter.endInterval("timeToFirstFrame", interval)
        firstFrameInterval = nil
    }

    private func apply(_ frame: TunerFrame) {
        endFirstFrameInterval()
        if reading != frame.reading { reading = frame.reading }
        let state = TuneState(frame.reading)
        if tuneState != state { tuneState = state }
        if detectedNote != frame.reading?.note { detectedNote = frame.reading?.note }
        if detectedString != frame.reading?.stringIndex { detectedString = frame.reading?.stringIndex }
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
            let remaining = restartBudget - 1
            Self.logger.info("audio route changed; restarting (\(remaining) left)")
            status = .idle
            await start(restartBudget: remaining)
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
        let resumptions = inputs.resumptions()
        let powerChanges = power.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inputChanges { await self?.reconcileSelectedInput() }
            }
            group.addTask { [weak self] in
                for await _ in resumptions { await self?.resumeAfterInterruption() }
            }
            group.addTask { [weak self] in
                for await _ in powerChanges { await self?.updatePowerProfile() }
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

    /// A phone call or Siri interrupted listening and has now finished: carry on where the user was,
    /// as the system asks. Only an interruption is resumed; any other state is left alone.
    private func resumeAfterInterruption() async {
        guard failure == .interrupted else { return }
        Self.logger.info("interruption ended; resuming")
        status = .idle
        await start()
    }

    private func updatePowerProfile() {
        let profile = power.current()
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
