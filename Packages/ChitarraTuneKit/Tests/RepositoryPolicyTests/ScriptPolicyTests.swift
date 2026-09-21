import Foundation
import Testing

/// The scripts a maintainer runs. `Scripts/lib/` holds what they share, which is sourced, not run.
private let maintainerScripts: [URL] = Repo.files(in: "Scripts", extensions: ["sh"])
    .filter { !$0.path.contains("/lib/") }

/// The scripts in `Scripts/` are the maintainer's tools. They are not installed on the PATH, so they
/// have no manual page: `--help` is it (ADR 0021 rule 8). These tests check that every one of them answers
/// it, with its own header, before it looks at its arguments or touches anything.
@Suite("Every script explains itself")
struct ScriptPolicyTests {
    private static func run(_ script: URL, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }

    @Test("There are scripts, and each one is an executable bash script with a header")
    func shape() throws {
        #expect(maintainerScripts.count >= 9)
        #expect(Repo.exists("Scripts/lib/help.sh"), "the shared --help handler")
        for script in maintainerScripts {
            let name = Repo.relativePath(script)
            #expect(FileManager.default.isExecutableFile(atPath: script.path), "\(name) is not executable")
            let lines = try Repo.text(name).components(separatedBy: "\n")
            #expect(lines.first == "#!/usr/bin/env bash", "\(name) does not start with the bash shebang")
            #expect(lines.dropFirst().first?.hasPrefix("# ") == true, "\(name) has no header comment to print")
            // Sourced right after the shell options, so --help answers before any argument check.
            let options = try #require(lines.firstIndex(of: "set -euo pipefail"), "\(name) sets no shell options")
            #expect(lines[options + 1] == #"source "$(dirname "$0")/lib/help.sh""#,
                    "\(name) must source lib/help.sh right after `set -euo pipefail`")
        }
    }

    @Test("--help and -h print the script's own header and exit 0", arguments: maintainerScripts, ["--help", "-h"])
    func help(script: URL, flag: String) throws {
        let name = Repo.relativePath(script)
        let result = try Self.run(script, [flag])
        #expect(result.status == 0, "\(name) \(flag) exited \(result.status)")
        let lines = result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 3, "\(name) \(flag) printed \(lines.count) lines")
        #expect(!lines.contains { $0.hasPrefix("#") }, "\(name) \(flag) printed the comment markers")
        #expect(result.output.contains(name), "\(name) \(flag) does not say how to run the script")
    }

    /// ADR 0017 rule 1: build output lives in one place outside the working tree, and the caller can
    /// move that place. A script that hard-codes a path inside the repository fills it with artifacts
    /// that iCloud then stamps with extended attributes, and code signing fails on them.
    @Test("Build output goes under the cache root, and the caller can move it", arguments: maintainerScripts)
    func buildOutput(script: URL) throws {
        let name = Repo.relativePath(script)
        let text = try Repo.text(name)
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), trimmed.contains("Library/Caches") else { continue }
            #expect(trimmed.contains("$HOME/Library/Caches/ChitarraTune"), "\(name): \(trimmed)")
            // `${SCRATCH:-…}` or `${WORK:-…}`: the cache is the default, never the only choice.
            #expect(trimmed.contains(":-"), "\(name): the cache path must be overridable")
        }
        for line in text.components(separatedBy: "\n") where line.contains("-derivedDataPath") {
            #expect(!line.contains("$ROOT/"), "\(name): derived data must not land in the working tree")
        }
        // Regression: `coverage-gate.sh` defaulted to `$PACKAGE/.build`, a second copy of the whole
        // build inside ~/Documents, where iCloud stamps it with the attributes that break signing.
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), trimmed.contains("BUILD=") || trimmed.contains("WORK=")
                    || trimmed.contains("SCRATCH=") || trimmed.contains("--scratch-path")
            else { continue }
            for inside in ["$ROOT/", "$PACKAGE/", "./"] {
                #expect(!trimmed.contains(inside), "\(name): builds in the working tree: \(trimmed)")
            }
        }
    }

    /// ADR 0017 rules 2 and 3: one build tree is long-lived — the package build, which the next run
    /// reuses — and every other one is one-shot and goes when the run succeeds, with `KEEP_BUILD=1`
    /// for the runs somebody needs to look inside.
    ///
    /// The exemptions are named here rather than inferred, so adding one is a visible edit.
    static let keepsItsTree: Set = [
        // The package build itself (ADR 0017 rule 2). Deleting it made every pre-push cold.
        "Scripts/coverage-gate.sh",
        // The cleaner names xcodebuild only to refuse to run while one is going.
        "Scripts/clean-caches.sh",
    ]

    @Test("A one-shot build tree goes when the run succeeds", arguments: maintainerScripts)
    func leavesNothingBehind(script: URL) throws {
        let name = Repo.relativePath(script)
        let text = try Repo.text(name)
        guard !Self.keepsItsTree.contains(name) else { return }
        let builds = ["swift build", "swift test", "xcodebuild ", "-derivedDataPath", "--scratch-path"]
        guard builds.contains(where: text.contains) else { return }
        #expect(text.contains("KEEP_BUILD"), "\(name) builds but offers no KEEP_BUILD escape hatch")
        #expect(text.contains("rm -rf"), "\(name) builds but never removes what it built")
    }

    /// ADR 0017 rule 2: the one tree that survives a green run is the package build, and `verify.sh`
    /// is what tells whoever is working how big the cache has become.
    @Test("The package build survives a green run, and the cache is reported")
    func packageBuildIsReused() throws {
        let gate = try Repo.text("Scripts/coverage-gate.sh")
        #expect(!gate.contains("rm -rf"), "the package build must outlive a passing run (ADR 0017 rule 2)")
        let verify = try Repo.text("Scripts/verify.sh")
        #expect(verify.contains("du -sk") || verify.contains("du -sh"), "verify.sh must report what the cache holds")
        #expect(verify.contains("Scripts/clean-caches.sh"), "verify.sh must name the command that empties it")
    }

    /// ADR 0019 rules 1 and 6: the hook is the gate in practice, so it lints the shell too — and
    /// says so plainly rather than failing when a contributor has not fetched the pinned tools.
    @Test("The local gate lints the shell and the workflows")
    func verifyLintsTheProcess() throws {
        let verify = try Repo.text("Scripts/verify.sh")
        #expect(verify.contains("shellcheck -x --severity=warning") || verify.contains(#""$SHELLCHECK" -x --severity=warning"#),
                "Scripts/verify.sh must run shellcheck at the agreed severity")
        #expect(verify.contains("ACTIONLINT"), "Scripts/verify.sh must run actionlint")
        // Each linter says, by name, how to get it and that CI runs it anyway — counting a shared
        // phrase was the first version of this check, and it counted SwiftLint's message too.
        for linter in ["swiftlint", "shellcheck", "actionlint"] {
            #expect(verify.contains("\(linter) is not here (Scripts/fetch-tools.sh); CI will run it."),
                    "a missing \(linter) must be said out loud, not silently skipped (ADR 0019 rule 6)")
        }
        #expect(Repo.exists("Scripts/fetch-tools.sh"), "the message must name a script that exists")
    }

    /// ADR 0018: the tests are arithmetic, so the optimisation level is the gate's speed. Debug is
    /// three and a half minutes and release is twenty-five seconds, for line-for-line the same
    /// coverage — and a gate slow enough to be worth skipping is a gate that gets skipped.
    @Test("The gate compiles the tests optimised, and every command that builds it agrees")
    func testsRunOptimised() throws {
        let gate = try Repo.text("Scripts/coverage-gate.sh")
        #expect(gate.contains("-c \"$CONFIGURATION\"") && gate.contains(#"CONFIGURATION="${CONFIGURATION:-release}""#),
                "the coverage gate must compile optimised, and let a debugger session ask for debug")
        for flag in ["-Xswiftc -enable-testing", "-Xswiftc -warnings-as-errors"] {
            #expect(gate.contains(flag), "the coverage gate must pass \(flag)")
        }
        // SwiftPM plans one build per set of flags: differ by one and the package compiles twice.
        let verify = try Repo.text("Scripts/verify.sh")
        for flag in ["-c release", "-Xswiftc -enable-testing", "-Xswiftc -warnings-as-errors"] {
            #expect(verify.contains(flag), "Scripts/verify.sh builds with different flags than the gate: \(flag)")
        }
    }

    /// ADR 0017 rule 5, and the reason it exists: `Packages/ChitarraTuneKit/.build` held 211 MB of
    /// iCloud-synced build output, put there by two workflow steps that ran `swift build` and
    /// `swift test` without naming a scratch path. Nothing noticed, because nothing looked.
    @Test("No build tree inside the working tree")
    func nothingBuildsInTheTree() {
        for path in ["Packages/ChitarraTuneKit/.build", "build", "DerivedData", "Packages/ChitarraTuneKit/.swiftpm/cache"] {
            #expect(!Repo.exists(path),
                    "\(path) is build output inside the working tree (ADR 0017 rule 5); Scripts/clean-caches.sh and `rm -rf \(path)`")
        }
    }

    /// The one command that empties the cache. It is destructive by design, so what it refuses to do
    /// matters as much as what it does.
    @Test("The cleanup script exists, previews without deleting, and guards the root")
    func cleanup() throws {
        #expect(Repo.exists("Scripts/clean-caches.sh"))
        let text = try Repo.text("Scripts/clean-caches.sh")
        #expect(text.contains("*/ChitarraTune) ;;"), "it must refuse a root that is not this project's cache")
        #expect(text.contains("$entry/.git"), "it must never delete a git worktree")

        // ADR 0017 rule 7, both halves of it. The guard used to be written
        // `! $DRY && pgrep -xq xcodebuild || ! $DRY && pgrep -xq swift-frontend`, and `&&`/`||` bind
        // left to right, so the whole condition reduced to "swift-frontend is running": the cleaner
        // would happily delete a tree an `xcodebuild` was writing into. A list, checked one name at a
        // time, cannot be got wrong that way, and this is what says both names are in it.
        let builders = try #require(text.firstMatch(of: #/\nBUILDERS=\(([^)]*)\)/#)?.output.1,
                                    "the build-in-flight guard must name the processes in one list")
        for builder in ["xcodebuild", "swift-frontend"] {
            #expect(builders.contains(builder), "the cleaner must refuse to run while \(builder) is going")
        }

        // A dry run against a cache that is not there says so, exits 0 and creates nothing. The path
        // is outside the working tree: nothing may build there, not even a path that is never made
        // (ADR 0017 rule 5). The name still has to end in /ChitarraTune, which the script demands.
        let absent = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent-\(UUID().uuidString)/ChitarraTune").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [Repo.url("Scripts/clean-caches.sh").path, "--dry-run"]
        process.environment = ProcessInfo.processInfo.environment.merging(["CACHE": absent]) { _, new in new }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(output)")
        #expect(!FileManager.default.fileExists(atPath: absent), "a dry run must create nothing")
    }

    /// ADR 0017 rule 7: the pinned linters are downloads, not build output. `Scripts/clean-caches.sh`
    /// kept only `swiftlint-*`, so a plain run deleted shellcheck and actionlint — while its own
    /// header, `Scripts/fetch-tools.sh`, `Scripts/verify.sh` and ADR 0019 all said it left them
    /// alone. The two scripts are compared here rather than read by a person, so adding a fourth tool
    /// to one of them and not the other fails the gate.
    @Test("Every tool the fetcher installs is one the cleaner keeps")
    func pinnedToolsSurviveTheCleaner() throws {
        let fetched = try Repo.text("Scripts/fetch-tools.sh")
            .matches(of: #/\nfetch ([a-z0-9]+)\x20/#)
            .map { String($0.output.1) }
        #expect(fetched.count >= 3, "Scripts/fetch-tools.sh fetches \(fetched)")
        let cleaner = try Repo.text("Scripts/clean-caches.sh")
        let kept = try #require(cleaner.firstMatch(of: #/\n *case "\$name" in\n *([^)]*)\)/#)?.output.1,
                                "the cleaner must keep the pinned tools in one `case` branch")
        for tool in fetched {
            #expect(kept.contains("\(tool)-*"), "Scripts/clean-caches.sh deletes the pinned \(tool)")
        }
    }

    /// Regression: `--help` used to be unknown, so a script with required arguments answered it with
    /// its usage error. Help comes first, whatever the script needs.
    @Test("A script that needs arguments still answers --help")
    func helpBeforeArguments() throws {
        let versioned = Repo.url("Scripts/bump-version.sh")
        #expect(try Self.run(versioned, ["--help"]).status == 0)
        #expect(try Self.run(versioned, []).status != 0, "without a version it must fail")
    }
}
