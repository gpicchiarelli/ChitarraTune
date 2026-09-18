import MetricKit
import TunerAudio

/// Receives the system's daily on-device metrics (CPU time, energy, hangs, crashes) and writes a
/// short summary to the log. MetricKit data never leaves the device through this app.
final class MetricsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsReporter()

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
        for payload in payloads {
            let hangs = payload.hangDiagnostics?.count ?? 0
            let crashes = payload.crashDiagnostics?.count ?? 0
            TunerLog.app.error("MetricKit diagnostics: \(hangs) hang(s), \(crashes) crash(es)")
        }
    }
}
