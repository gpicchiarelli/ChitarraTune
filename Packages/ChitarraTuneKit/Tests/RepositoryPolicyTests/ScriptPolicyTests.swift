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

    /// Regression: `--help` used to be unknown, so a script with required arguments answered it with
    /// its usage error. Help comes first, whatever the script needs.
    @Test("A script that needs arguments still answers --help")
    func helpBeforeArguments() throws {
        let versioned = Repo.url("Scripts/bump-version.sh")
        #expect(try Self.run(versioned, ["--help"]).status == 0)
        #expect(try Self.run(versioned, []).status != 0, "without a version it must fail")
    }
}
