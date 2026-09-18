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
        let constrained = processInfo.isLowPowerModeEnabled
            || processInfo.thermalState == .serious
            || processInfo.thermalState == .critical
        return constrained ? .efficient : .standard
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
