import Foundation
import TunerCore

/// How aggressively the tuner may spend energy, derived from the device power state.
///
/// In Low Power Mode or under thermal pressure the analysis rate drops from ~40 Hz to ~22 Hz.
/// A tuner needle does not need more, and the CPU/GPU saving is proportional.
public enum PowerProfile: Sendable, Hashable {
    case standard
    case efficient

    public static func current(_ processInfo: ProcessInfo = .processInfo) -> PowerProfile {
        profile(lowPowerMode: processInfo.isLowPowerModeEnabled, thermalState: processInfo.thermalState)
    }

    /// The profile for a given power state: efficient in Low Power Mode or under serious thermal pressure.
    public static func profile(lowPowerMode: Bool, thermalState: ProcessInfo.ThermalState) -> PowerProfile {
        lowPowerMode || thermalState == .serious || thermalState == .critical ? .efficient : .standard
    }

    public var engineParameters: EngineParameters {
        var parameters = EngineParameters.standard
        if self == .efficient { parameters.hopDuration = 0.045 }
        return parameters
    }

    /// Emits whenever Low Power Mode or the thermal state may have changed. Event-driven.
    public static func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let center = NotificationCenter.default
            nonisolated(unsafe) let tokens = [
                center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil) { _ in
                    continuation.yield()
                },
                center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil) { _ in
                    continuation.yield()
                },
            ]
            continuation.onTermination = { _ in tokens.forEach(center.removeObserver) }
        }
    }
}

/// Where a tuner reads the power state from: the real device by default, a fake in tests.
public struct PowerSource: Sendable {
    public var current: @Sendable () -> PowerProfile
    public var changes: @Sendable () -> AsyncStream<Void>

    public init(current: @escaping @Sendable () -> PowerProfile, changes: @escaping @Sendable () -> AsyncStream<Void>) {
        self.current = current
        self.changes = changes
    }

    /// Low Power Mode and thermal state of this device.
    public static let system = PowerSource(current: { PowerProfile.current() }, changes: { PowerProfile.changes() })
}
