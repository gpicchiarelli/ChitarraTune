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
        let guarded = try #require(options.firstRange(of: "#if DEBUG\n    private static let arguments = ProcessInfo.processInfo.arguments\n    #else\n    private static let arguments: [String] = []\n    #endif"),
                                   "LaunchOptions must read launch arguments only in Debug builds")
        #expect(options.components(separatedBy: "ProcessInfo.processInfo.arguments").count == 2, "arguments are read elsewhere too")
        #expect(!guarded.isEmpty)
        let hooks = Self.shipped.filter { $0.code.contains("ProcessInfo.processInfo.arguments") || $0.code.contains("ProcessInfo.processInfo.environment") }
        #expect(hooks.map(\.path) == ["App/Platform/FocusedValues+LaunchOptions.swift"], "other test switches: \(hooks.map(\.path))")

        let scheme = try Repo.text("ChitarraTune.xcodeproj/xcshareddata/xcschemes/ChitarraTune.xcscheme")
        #expect(scheme.contains(/<TestAction\s+buildConfiguration = "Debug"/))
        #expect(scheme.contains(/<ArchiveAction\s+buildConfiguration = "Release"/))
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
        }
        for (token, allowed) in Self.auditedUnsafe {
            let users = Self.shipped.filter { $0.code.contains(token) }.map(\.path)
            #expect(users == allowed, "\(token) is used in \(users), audited: \(allowed)")
        }
    }
}
