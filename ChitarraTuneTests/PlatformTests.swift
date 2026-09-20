import Foundation
import Testing
import TunerAudio
@testable import ChitarraTune

/// The app's own platform code: the launch arguments that only Debug builds honour (ADR 0006), the
/// summaries MetricKit leaves for the next session, and the report a user can copy (ADR 0004).
@Suite("Platform")
struct PlatformTests {
    /// Preferences of their own, so a test never reads or writes the ones the app uses.
    private func scratchDefaults() throws -> UserDefaults {
        let suite = "tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suite))
    }

    /// The test bundle runs the app without any of the demo arguments: every hook must be off, which
    /// is also what a shipping build gets, since a Release build ignores the arguments altogether.
    @Test("Without its launch arguments the app is in no demo state at all")
    func launchOptionsDefaults() {
        #expect(LaunchOptions.isDemo == false)
        #expect(LaunchOptions.autostart == false)
        #expect(LaunchOptions.demoPermission == .authorized, "only demo mode may fake a permission")
        #expect(LaunchOptions.demoColorScheme == nil)
    }

    @Test("Only the newest session summaries are kept")
    func metricsStorageKeepsTheNewest() throws {
        let defaults = try scratchDefaults()
        MetricsReporter.store(["one", "two"], in: defaults)
        #expect(MetricsReporter.previousSessions(defaults) == ["one", "two"])

        let many = (1...MetricsReporter.limit + 3).map { "crash \($0)" }
        MetricsReporter.store(many, in: defaults)
        let kept = MetricsReporter.previousSessions(defaults)
        #expect(kept.count == MetricsReporter.limit)
        #expect(kept.last == many.last, "the newest summary must survive")
        #expect(!kept.contains("one"), "the oldest must be dropped")

        MetricsReporter.store([], in: defaults)
        #expect(MetricsReporter.previousSessions(defaults) == kept, "nothing to add must change nothing")
    }

    @Test("The report a user copies names the build and the earlier sessions, and nothing else")
    func diagnosticsReport() async throws {
        let defaults = try scratchDefaults()
        let empty = await Diagnostics.report(since: 60, defaults: defaults)
        #expect(empty.hasPrefix(BuildInfo.summary), "the build is the first thing a bug report needs")
        #expect(!empty.contains("Earlier sessions"), "there were none")

        MetricsReporter.store(["2026-09-20 crash in build 42: signal 11"], in: defaults)
        let report = await Diagnostics.report(since: 60, defaults: defaults)
        #expect(report.contains("Earlier sessions (MetricKit):"))
        #expect(report.contains("crash in build 42"))
        // The log lines the report carries are the app's own, and nothing it logs is audio.
        for line in report.split(separator: "\n") where line.contains("[capture]") {
            #expect(!line.lowercased().contains("sample"), "a log line leaked signal data: \(line)")
        }
    }

    /// Regression: reading the log store is synchronous and took about thirteen seconds here. On the
    /// main actor — the app's default isolation — *Copy Diagnostics* would freeze the window for that
    /// long. The window must stay responsive while the report is built.
    @Test("Building the report leaves the main actor free")
    func reportDoesNotBlockTheMainActor() async {
        let clock = ContinuousClock()
        let started = clock.now
        async let report = Diagnostics.report()

        // Work the main actor the way the interface would while the report is being built.
        var mainActorHops = 0
        while mainActorHops < 200 {
            await Task.yield()
            mainActorHops += 1
        }
        let mainActorTime = clock.now - started
        _ = await report
        let reportTime = clock.now - started

        // An empty log store answers at once and proves nothing; a slow one must not hold the actor.
        if reportTime > .seconds(1) {
            #expect(mainActorTime < reportTime / 2, "the main actor was busy for \(mainActorTime) of \(reportTime)")
        }
    }
}
