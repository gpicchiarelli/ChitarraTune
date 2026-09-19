import Foundation
import MetricKit
import os
import TunerAudio

/// Receives the system's on-device metrics and diagnostics (CPU time, energy, hangs, crashes) and
/// writes a short summary to the log. MetricKit data never leaves the device through this app.
///
/// Crash and hang diagnostics arrive at the *next* launch, when the log of the session that failed
/// is no longer readable (`OSLogStore` only sees the current process). A one-line summary of the
/// latest ones is therefore kept in the app's own preferences for *Copy Diagnostics*: build,
/// exception type, signal and termination reason. No audio, no stack contents, no personal data.
final class MetricsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsReporter()

    /// Preferences key of the stored summaries (newest last).
    nonisolated static let storageKey = "diagnostics.previousSessions"
    /// How many summaries are kept.
    nonisolated static let limit = 5

    func start() {
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let cpu = payload.cpuMetrics?.cumulativeCPUTime.converted(to: .seconds).value ?? 0
            let foreground = payload.applicationTimeMetrics?.cumulativeForegroundTime.converted(to: .seconds).value ?? 0
            TunerLog.app.info("""
                MetricKit payload: foreground \(foreground, format: .fixed(precision: 0)) s, \
                CPU \(cpu, format: .fixed(precision: 1)) s
                """)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var summaries: [String] = []
        for payload in payloads {
            let hangs = payload.hangDiagnostics?.count ?? 0
            let crashes = payload.crashDiagnostics?.count ?? 0
            TunerLog.app.error("MetricKit diagnostics: \(hangs) hang(s), \(crashes) crash(es)")
            let period = payload.timeStampBegin.formatted(.iso8601)
            for crash in payload.crashDiagnostics ?? [] {
                summaries.append(Self.summary(of: crash, period: period))
            }
            if hangs > 0 { summaries.append("\(period) \(hangs) hang(s)") }
        }
        guard !summaries.isEmpty else { return }
        let defaults = UserDefaults.standard
        let kept = (defaults.stringArray(forKey: Self.storageKey) ?? []) + summaries
        defaults.set(Array(kept.suffix(Self.limit)), forKey: Self.storageKey)
    }

    /// One line about a crash: when, which build, and how it ended.
    nonisolated static func summary(of crash: MXCrashDiagnostic, period: String) -> String {
        let build = crash.metaData.applicationBuildVersion
        let exception = crash.exceptionType.map { "exception \($0)" } ?? "no exception"
        let signal = crash.signal.map { "signal \($0)" } ?? "no signal"
        let reason = crash.terminationReason ?? "no termination reason"
        return "\(period) crash in build \(build): \(exception), \(signal), \(reason)"
    }

    /// The stored summaries, oldest first.
    nonisolated static func previousSessions(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }
}
