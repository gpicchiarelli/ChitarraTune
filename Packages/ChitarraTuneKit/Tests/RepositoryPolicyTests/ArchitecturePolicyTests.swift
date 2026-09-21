import Foundation
import Testing

/// Enforces the ADRs that are about the code itself, by reading every source file.
@Suite("Architecture policy")
struct ArchitecturePolicyTests {
    /// A source file with its comment lines removed (rules apply to code, not to prose about it).
    struct Source: CustomTestStringConvertible, Sendable {
        let path: String
        let code: String
        var testDescription: String { path }
        var imports: Set<String> {
            Set(code.split(separator: "\n").compactMap { line in
                line.wholeMatch(of: /(?:@testable |public |internal )?import (\w+)\s*/).map { String($0.output.1) }
            })
        }
    }

    static func sources(in directories: [String]) -> [Source] {
        directories.flatMap { Repo.files(in: $0, extensions: ["swift"]) }.map { url in
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
                .joined(separator: "\n")
            return Source(path: Repo.relativePath(url), code: code)
        }
    }

    static let shipped = sources(in: ["App", "Shared", "Controls", "Packages/ChitarraTuneKit/Sources"])

    // MARK: ADR 0002 — audio never leaves memory

    @Test("ADR 0002: no code can record, store, export or share audio", arguments: shipped)
    func audioNeverLeavesMemory(source: Source) {
        let forbidden = ["AVAudioRecorder", "AVAudioFile", "ExtAudioFile", "AudioFileCreate", "AudioFileOpen", "AudioFileWrite",
                         "AVAssetWriter", "AVCaptureAudioFileOutput", "AVAudioSinkNode", "fileExporter", "FileDocument", "ShareLink",
                         "Transferable", "DataRepresentation", "FileRepresentation", "NSSavePanel", "UIDocumentPicker",
                         ".write(to:", "createFile(", "FileHandle(", "\"RIFF\"", "\"WAVE\"", ".wav\"", "UTType.wav", ".wav]"]
        for token in forbidden {
            #expect(!source.code.contains(token), "\(source.path) uses \(token)")
        }
    }

    @Test("ADR 0002: only the capture actor installs an input tap")
    func singleTap() {
        let taps = Self.shipped.filter { $0.code.contains("installTap(") }.map(\.path)
        #expect(taps == ["Packages/ChitarraTuneKit/Sources/TunerAudio/EngineAudioCapture.swift"])
    }

    @Test("The scan sees the whole code base")
    func scanCoverage() {
        #expect(Self.shipped.count > 40, "found only \(Self.shipped.count) source files")
        #expect(Self.shipped.contains { $0.path.hasSuffix("TuningEngine.swift") })
        #expect(Self.shipped.contains { $0.path.hasSuffix("ChitarraTuneControls.swift") })
    }

    // MARK: ADR 0004 — logging

    /// `\(value, privacy: .public)` in a log message; `value` may contain one level of parentheses.
    nonisolated(unsafe) static let publicInterpolation = /\\\(([^()]*(?:\([^()]*\))?[^()]*), privacy: \.public\)/

    @Test("ADR 0004: logging goes through Unified Logging and never publishes descriptions or device identities", arguments: shipped)
    func logging(source: Source) {
        for token in ["print(", "NSLog(", "debugPrint(", "dump("] {
            #expect(!source.code.contains(token), "\(source.path) uses \(token)")
        }
        for match in source.code.matches(of: Self.publicInterpolation) {
            let value = String(match.output.1)
            for leak in ["localizedDescription", "uid", "UID", "name", "Name", "path", "url", "URL", "samples"] {
                #expect(!value.contains(leak), "\(source.path) logs \(value) publicly")
            }
        }
    }

    @Test("ADR 0004: the logging scan recognises public interpolations")
    func loggingScanWorks() {
        let found = Self.shipped.flatMap { $0.code.matches(of: Self.publicInterpolation) }
        #expect(found.count >= 5, "the scan found only \(found.count) public interpolations; is the pattern broken?")
    }

    // MARK: ADR 0005 — module boundaries

    @Test("ADR 0005: every module imports only what its layer allows", arguments: [
        ("Packages/ChitarraTuneKit/Sources/TunerCore", ["Foundation", "Accelerate"]),
        ("Packages/ChitarraTuneKit/Sources/TunerAudio", ["Foundation", "Accelerate", "AVFoundation", "CoreAudio", "Synchronization", "os", "TunerCore"]),
        ("Packages/ChitarraTuneKit/Sources/TunerFeature", ["Foundation", "Observation", "os", "TunerCore", "TunerAudio"]),
        ("Controls", ["AppIntents", "SwiftUI", "WidgetKit"]),
        ("Shared", ["AppIntents", "TunerFeature"]),
    ])
    func moduleImports(directory: String, allowed: [String]) {
        let files = Self.sources(in: [directory])
        #expect(!files.isEmpty, "\(directory) has no sources")
        for file in files {
            let extra = file.imports.subtracting(allowed)
            #expect(extra.isEmpty, "\(file.path) imports \(extra.sorted()), which its layer does not allow")
        }
    }

    // MARK: ADR 0006 — test hooks

    @Test("ADR 0006: launch-argument hooks exist only in Debug builds; tests run Debug, archives Release")
    func testHooksOnlyInDebug() throws {
        let options = try Repo.text("App/Platform/FocusedValues+LaunchOptions.swift")
        let guarded = """
            #if DEBUG
                private static let arguments = ProcessInfo.processInfo.arguments
                #else
                private static let arguments: [String] = []
                #endif
            """
        #expect(options.contains(guarded), "LaunchOptions must read launch arguments only in Debug builds")
        #expect(options.components(separatedBy: "ProcessInfo.processInfo.arguments").count == 2, "arguments are read elsewhere too")
        let hooks = Self.shipped.filter { $0.code.contains("ProcessInfo.processInfo.arguments") || $0.code.contains("ProcessInfo.processInfo.environment") }
        #expect(hooks.map(\.path) == ["App/Platform/FocusedValues+LaunchOptions.swift"], "other test switches: \(hooks.map(\.path))")

        let scheme = try Repo.text("ChitarraTune.xcodeproj/xcshareddata/xcschemes/ChitarraTune.xcscheme")
        #expect(scheme.contains(/<TestAction\s+buildConfiguration = "Debug"/))
        #expect(scheme.contains(/<ArchiveAction\s+buildConfiguration = "Release"/))
    }

    // MARK: ADR 0012 — windows and sessions

    @Test("ADR 0012: one scene on iPhone and iPad, a bounded quit, no listening without a window")
    func windowsAndSessions() throws {
        let info = try Repo.plist("Config/Info.plist")
        let manifest = try #require(info["UIApplicationSceneManifest"] as? [String: Any])
        #expect(manifest["UIApplicationSupportsMultipleScenes"] as? Bool == false)
        let settings = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        #expect(settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] == "NO",
                "a generated manifest would replace the one in Config/Info.plist")

        let delegate = try Repo.text("App/Platform/AppDelegate.swift")
        #expect(delegate.contains("static let quitTimeout = Duration.seconds(2)"))
        #expect(delegate.contains("Task.sleep(for: Self.quitTimeout)"))
        // Rule 4 lives in one place, so that it is kept for every entry point and not only for the
        // one somebody remembered. It used to be written into the Dock menu alone, and Siri,
        // Shortcuts, the Action Button and the Control Center button — all of them `StartTuningIntent`
        // — started the microphone with no window check at all.
        let hub = try Repo.text("Packages/ChitarraTuneKit/Sources/TunerFeature/TunerHub.swift")
        let rule = try #require(hub.components(separatedBy: "func startOnVisibleTuner").last)
        for step in ["hasVisibleTuner", "presentTuner?()", "waitForVisibleTuner"] {
            #expect(rule.contains(step), "starting with no window must \(step) first")
        }
        // The scanned sources, not the files: a comment saying what the code no longer does is prose,
        // and prose is not a rule being broken.
        for path in ["Shared/StartTuningIntent.swift", "App/Platform/AppDelegate.swift"] {
            let entry = try #require(Self.shipped.first { $0.path == path }, "\(path) is not scanned")
            #expect(entry.code.contains("startOnVisibleTuner"), "\(path) must start listening through the hub")
            #expect(!entry.code.contains(".start()"), "\(path) starts the microphone without asking for a window")
        }
        let window = try Repo.text("App/Tuner/TunerWindow.swift")
        #expect(window.contains("hub.activate(id)") && window.contains("hub.discard(id)"))
    }

    // MARK: ADR 0022 — the audio thread

    /// Files that run on the real-time tap thread, or are called from it.
    static let onTheAudioThread = ["Packages/ChitarraTuneKit/Sources/TunerAudio/ChannelSelector.swift"]

    /// ADR 0022 rules 1, 2 and 4, written as forbidden spellings because that is the kind of rule a
    /// reviewer forgets. The selector used to allocate a `[Float]` for the per-channel levels and take
    /// a `Mutex`, on every callback, on the one thread that must not wait for an allocator or for a
    /// thread the scheduler has just preempted.
    @Test("ADR 0022: the audio thread neither allocates, nor locks, nor logs")
    func audioThread() throws {
        let forbidden = [
            "[Float](repeating:", "[Double](repeating:", "Array(repeating:", "ContiguousArray(",
            "Mutex", "NSLock", "os_unfair_lock", "DispatchQueue", "DispatchSemaphore",
            "Logger", "print(", "String(format:", "NumberFormatter", "Date(",
        ]
        for path in Self.onTheAudioThread {
            let source = try #require(Self.shipped.first { $0.path == path }, "\(path) is not scanned")
            for token in forbidden {
                #expect(!source.code.contains(token), "\(path) does \(token) on the audio thread")
            }
            #expect(source.code.contains("withUnsafeTemporaryAllocation"), "\(path): scratch must be stack memory")
            #expect(source.code.contains("Atomic<"), "\(path): shared state must be atomic, not locked")
        }
        // Rule 3: the one allocation allowed there is the one that carries the samples away.
        let selector = try #require(Self.shipped.first { $0.path == Self.onTheAudioThread[0] })
        #expect(selector.code.components(separatedBy: "Array(").count - 1 == 1,
                "the samples are the only array the tap may build (ADR 0022 rule 3)")

        // And the tap block itself calls nothing but the selector and the stream.
        let capture = try Repo.text("Packages/ChitarraTuneKit/Sources/TunerAudio/EngineAudioCapture.swift")
        let body = try #require(capture.components(separatedBy: "installTap(onBus: 0").dropFirst().first?
            .components(separatedBy: "\n            }").first)
        for token in forbidden where token != "Logger" {
            #expect(!body.contains(token), "the tap block does \(token)")
        }
    }

    // MARK: ADR 0023 — the deployment target

    /// ADR 0023 rule 2. A deployment target at the current major version is what lets this code base
    /// have one concurrency story, one observation story and one security posture; an availability
    /// fence inside these sources means the target is wrong, not that the check is clever.
    @Test("ADR 0023: no availability fences in the app's own sources", arguments: shipped)
    func noAvailabilityFences(source: Source) {
        for token in ["#available", "@available(macOS", "@available(iOS"] {
            #expect(!source.code.contains(token), "\(source.path) carries \(token)")
        }
    }

    // MARK: ADR 0007 — concurrency

    /// The audited escape hatches, each with the reason it is safe written next to it in the code.
    static let auditedUnsafe: [String: [String]] = [
        "nonisolated(unsafe)": ["Packages/ChitarraTuneKit/Sources/TunerAudio/Hardware/SystemAudioInputs.swift"],
        "MainActor.assumeIsolated": ["App/Platform/WindowLifecycle.swift"],
    ]

    @Test("ADR 0007: no unchecked Sendable, no sleeping threads, escape hatches only where audited")
    func concurrencyEscapeHatches() {
        let tests = Self.sources(in: ["ChitarraTuneUITests"])
        for source in Self.shipped + tests {
            #expect(!source.code.contains("@unchecked Sendable"), "\(source.path) uses @unchecked Sendable")
            #expect(!source.code.contains("Thread.sleep") && !source.code.contains("usleep("), "\(source.path) sleeps a thread")
            #expect(!source.code.contains("Task.sleep(for: .milliseconds("), "\(source.path) polls: wait for an event instead")
        }
        for (token, allowed) in Self.auditedUnsafe {
            let users = Self.shipped.filter { $0.code.contains(token) }.map(\.path)
            #expect(users == allowed, "\(token) is used in \(users), audited: \(allowed)")
        }
    }
}
