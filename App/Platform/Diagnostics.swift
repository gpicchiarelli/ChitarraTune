import Foundation
import OSLog
import TunerAudio

/// Builds a plain-text report a user can paste into a bug report: version, system, a summary of the
/// crashes and hangs MetricKit reported for earlier sessions, and the app's own recent log lines. It
/// reads only this process's log store and contains no audio or personal data (dynamic values are
/// logged as private and appear redacted).
enum Diagnostics {
    static func report(since interval: TimeInterval = 15 * 60, defaults: UserDefaults = .standard) async -> String {
        var lines = [BuildInfo.summary, ""]
        let previous = MetricsReporter.previousSessions(defaults)
        if !previous.isEmpty {
            lines.append("Earlier sessions (MetricKit):")
            lines += previous.map { "  " + $0 }
            lines.append("")
        }
        lines += await logLines(since: interval)
        return lines.joined(separator: "\n")
    }

    /// The app's own log entries of the last `interval`, oldest first.
    ///
    /// Reading the log store is synchronous and takes seconds on a busy device, so this runs off the
    /// main actor (`@concurrent`): copying the report must never freeze the window.
    @concurrent nonisolated private static func logLines(since interval: TimeInterval) async -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let start = store.position(date: Date(timeIntervalSinceNow: -interval))
            let entries = try store.getEntries(
                at: start,
                matching: NSPredicate(format: "subsystem == %@", TunerLog.subsystem)
            )
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return entries.compactMap { entry in
                guard let entry = entry as? OSLogEntryLog else { return nil }
                return "\(formatter.string(from: entry.date)) [\(entry.category)] \(entry.composedMessage)"
            }
        } catch {
            return ["Log store unavailable: \(error.localizedDescription)"]
        }
    }
}
