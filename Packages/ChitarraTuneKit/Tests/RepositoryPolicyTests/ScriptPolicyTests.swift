import Foundation
import Testing

/// The scripts a maintainer runs. `Scripts/lib/` holds what they share, which is sourced, not run.
private let maintainerScripts: [URL] = Repo.files(in: "Scripts", extensions: ["sh"])
    .filter { !$0.path.contains("/lib/") }

/// The scripts in `Scripts/` are the maintainer's tools. They are not installed on the PATH, so they
/// have no manual page: `--help` is it (ADR 0009). These tests check that every one of them answers
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

    /// ADR 0016: build output lives in one place outside the working tree, and the caller can move
    /// that place. A script that hard-codes a path inside the repository fills it with artifacts
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

    /// ADR 0016 rule 2: a run that succeeds leaves its artifact and nothing else. A script that
    /// builds must therefore end by removing what it built, and must take `KEEP_BUILD=1` for the
    /// runs somebody needs to look inside.
    @Test("A script that builds takes its build tree away again", arguments: maintainerScripts)
    func leavesNothingBehind(script: URL) throws {
        let name = Repo.relativePath(script)
        let text = try Repo.text(name)
        // The cleaner names xcodebuild only to refuse to run while one is going.
        guard name != "Scripts/clean-caches.sh" else { return }
        let builds = ["swift build", "swift test", "xcodebuild ", "-derivedDataPath", "--scratch-path"]
        guard builds.contains(where: text.contains) else { return }
        #expect(text.contains("KEEP_BUILD"), "\(name) builds but offers no KEEP_BUILD escape hatch")
        #expect(text.contains("rm -rf"), "\(name) builds but never removes what it built")
    }

    /// The one command that empties the cache. It is destructive by design, so what it refuses to do
    /// matters as much as what it does.
    @Test("The cleanup script exists, previews without deleting, and guards the root")
    func cleanup() throws {
        #expect(Repo.exists("Scripts/clean-caches.sh"))
        let text = try Repo.text("Scripts/clean-caches.sh")
        #expect(text.contains("*/ChitarraTune) ;;"), "it must refuse a root that is not this project's cache")
        #expect(text.contains("$entry/.git"), "it must never delete a git worktree")
        #expect(text.contains("pgrep"), "it must refuse to run while a build is in flight")

        // A dry run against a cache that is not there says so, exits 0 and creates nothing.
        let absent = Repo.url("Packages/ChitarraTuneKit/.build/absent-cache/ChitarraTune").path
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

    /// Regression: `--help` used to be unknown, so a script with required arguments answered it with
    /// its usage error. Help comes first, whatever the script needs.
    @Test("A script that needs arguments still answers --help")
    func helpBeforeArguments() throws {
        let versioned = Repo.url("Scripts/bump-version.sh")
        #expect(try Self.run(versioned, ["--help"]).status == 0)
        #expect(try Self.run(versioned, []).status != 0, "without a version it must fail")
    }
}
