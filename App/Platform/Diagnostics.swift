import Foundation
import OSLog
import TunerAudio

/// Builds a plain-text report a user can paste into a bug report: version, system, a summary of the
/// crashes and hangs MetricKit reported for earlier sessions, and the app's own recent log lines. It
/// reads only this process's log store and contains no audio or personal data (dynamic values are
/// logged as private and appear redacted).
enum Diagnostics {
    static func report(since interval: TimeInterval = 15 * 60) async -> String {
        var lines = [BuildInfo.summary, ""]
        let previous = MetricsReporter.previousSessions()
        if !previous.isEmpty {
            lines.append("Earlier sessions (MetricKit):")
            lines += previous.map { "  " + $0 }
            lines.append("")
        }
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let start = store.position(date: Date(timeIntervalSinceNow: -interval))
            let entries = try store.getEntries(
                at: start,
                matching: NSPredicate(format: "subsystem == %@", TunerLog.subsystem)
            )
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for case let entry as OSLogEntryLog in entries {
                lines.append("\(formatter.string(from: entry.date)) [\(entry.category)] \(entry.composedMessage)")
            }
        } catch {
            lines.append("Log store unavailable: \(error.localizedDescription)")
        }
        return lines.joined(separator: "\n")
    }
}
