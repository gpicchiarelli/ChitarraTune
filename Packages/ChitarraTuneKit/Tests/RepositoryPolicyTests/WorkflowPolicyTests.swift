import Foundation
import Testing

/// Supply-chain rules for `.github/workflows`, enforced on every change to them.
@Suite("Workflow policy")
struct WorkflowPolicyTests {
    private var workflows: [URL] { Repo.files(in: ".github/workflows", extensions: ["yml", "yaml"]) }

    private func lines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
    }

    /// Runs a tool and returns its status and combined output, or `nil` if it cannot be launched.
    private func run(_ tool: String, _ arguments: [String]) -> (status: Int32, output: String)? {
        guard FileManager.default.isExecutableFile(atPath: tool) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }

    /// Regression: `- name: X (strict: y)` is not valid YAML, GitHub refused the whole workflow, and
    /// nothing in this repository noticed until after the push.
    @Test("Every workflow and issue form is syntactically valid YAML")
    func validYAML() {
        let files = (workflows + Repo.files(in: ".github/ISSUE_TEMPLATE", extensions: ["yml"]) + [Repo.url(".github/dependabot.yml")]).map(\.path)
        #expect(files.count >= 8)
        let parsers: [(tool: String, arguments: [String])] = [
            ("/usr/bin/ruby", ["-ryaml", "-e", "ARGV.each { |f| YAML.load_file(f) }"]),
            ("/usr/bin/python3", ["-c", "import sys, yaml\nfor f in sys.argv[1:]: yaml.safe_load(open(f))"]),
        ]
        var checked = false
        for parser in parsers {
            guard let result = run(parser.tool, parser.arguments + files) else { continue }
            if result.status == 0 { checked = true; break }
            if result.output.contains("ModuleNotFoundError") || result.output.contains("cannot load such file") { continue }
            Issue.record("invalid YAML: \(result.output)")
            checked = true
            break
        }
        #expect(checked, "neither ruby nor python3 with PyYAML is available to validate the YAML")
    }

    @Test("The expected workflows exist")
    func present() {
        let names = Set(workflows.map(\.lastPathComponent))
        #expect(names.isSuperset(of: ["ci.yml", "codeql.yml", "release.yml", "swiftlint.yml"]))
    }

    @Test("Every third-party action is pinned to a full commit SHA")
    func pinnedActions() throws {
        let pinned = try NSRegularExpression(pattern: #"@[0-9a-f]{40}(\s|$)"#)
        for file in workflows {
            for line in try lines(file) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("- uses:") || trimmed.hasPrefix("uses:") else { continue }
                let reference = trimmed.replacingOccurrences(of: "- ", with: "")
                guard !reference.contains("uses: ./") else { continue }
                #expect(pinned.firstMatch(in: reference, range: NSRange(reference.startIndex..., in: reference)) != nil,
                        "\(file.lastPathComponent): '\(trimmed)' is not pinned to a SHA")
            }
        }
    }

    @Test("Workflows declare least-privilege permissions, and only the release may write contents")
    func permissions() throws {
        for file in workflows {
            let all = try lines(file)
            #expect(all.contains { $0.hasPrefix("permissions:") }, "\(file.lastPathComponent) has no top-level permissions")
            #expect(!all.contains { $0.contains("write-all") }, "\(file.lastPathComponent) grants write-all")
            if file.lastPathComponent != "release.yml" {
                #expect(!all.contains { $0.contains("contents: write") }, "\(file.lastPathComponent) can write contents")
            }
        }
    }

    @Test("Every job has a timeout and every checkout drops its credentials")
    func hygiene() throws {
        for file in workflows {
            let text = try String(contentsOf: file, encoding: .utf8)
            let jobs = text.components(separatedBy: "runs-on:").count - 1
            #expect(text.components(separatedBy: "timeout-minutes:").count - 1 == jobs, "\(file.lastPathComponent): job without timeout")
            let checkouts = text.components(separatedBy: "actions/checkout@").count - 1
            #expect(text.components(separatedBy: "persist-credentials: false").count - 1 == checkouts,
                    "\(file.lastPathComponent): checkout keeps credentials")
        }
    }

    @Test("Container images are pinned to an explicit version, never `latest`")
    func pinnedImages() throws {
        for file in workflows {
            for line in try lines(file) where line.trimmingCharacters(in: .whitespaces).hasPrefix("image:") {
                let reference = line.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                #expect(reference.contains(":") && !reference.hasSuffix(":latest"),
                        "\(file.lastPathComponent): '\(reference)' must carry an explicit version tag so the gate is deterministic")
            }
        }
    }

    @Test("Untrusted event data never reaches a shell")
    func noInjection() throws {
        let dangerous = try NSRegularExpression(pattern: #"\$\{\{\s*github\.(event\.|head_ref)"#)
        for file in workflows {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(dangerous.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) == nil,
                    "\(file.lastPathComponent) interpolates attacker-controlled event data")
            #expect(!text.contains("pull_request_target"), "\(file.lastPathComponent) uses pull_request_target")
        }
    }

    @Test("Dependabot keeps the pinned actions current")
    func dependabot() throws {
        let config = try Repo.text(".github/dependabot.yml")
        #expect(config.contains("github-actions"))
    }

    @Test("CI runs the package tests, builds every platform, and has one aggregate gate")
    func ciShape() throws {
        let ci = try Repo.text(".github/workflows/ci.yml")
        #expect(ci.contains("coverage-gate.sh") && ci.contains("-warnings-as-errors"))
        #expect(ci.contains("platform=macOS") && ci.contains("generic/platform=iOS Simulator"))
        #expect(ci.contains("gate:"), "ci.yml needs the aggregate 'gate' job that branch protection requires")
        #expect(ci.contains("run: Scripts/release-check.sh"), "every push must build and check the Mac app as a release (ADR 0013)")
        #expect(ci.contains("needs: [kit, app, dsp, release, ui]"), "the gate must wait for every job")
        let release = try Repo.text(".github/workflows/release.yml")
        #expect(release.contains("Scripts/release-check.sh --verify build/Build/Products/Release/ChitarraTune.app --signed"),
                "the release must pass the same checks, on its signed build")
    }

    @Test("Both workflows build the disk image, and the release notarizes, staples and publishes it (ADR 0014)")
    func diskImage() throws {
        let ci = try Repo.text(".github/workflows/ci.yml")
        #expect(ci.contains("run: Scripts/make-dmg.sh"),
                "every push must build and check the disk image, ad hoc (ADR 0014)")
        let release = try Repo.text(".github/workflows/release.yml")
        #expect(release.contains(#"Scripts/make-dmg.sh "${ARGS[@]}""#), "the release publishes the image the script builds")
        #expect(release.contains("--notarize-key"), "the image is notarized in a submission of its own")
        #expect(release.contains(#"DMG="ChitarraTune-${VERSION}.dmg""#), "one artifact, named ChitarraTune-X.Y.Z.dmg")
        #expect(release.contains("subject-path: ${{ env.DMG }}"), "the attestation must cover the published image")
        #expect(release.contains(#"gh release create "$TAG" "$DMG" "$DMG.sha256""#),
                "the release publishes the image and its checksum, and nothing else")
        #expect(!release.contains("-macOS.zip"), "the zip channel is gone (ADR 0014)")
    }

    @Test("Runners are pinned to an explicit image, never a moving `-latest` label")
    func pinnedRunners() throws {
        for workflow in Repo.files(in: ".github/workflows", extensions: ["yml"]) {
            let text = try String(contentsOf: workflow, encoding: .utf8)
            for line in text.split(separator: "\n") where line.contains("runs-on:") {
                #expect(!line.contains("-latest"), "\(workflow.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    @Test("Repository health files exist")
    func communityFiles() {
        for path in [".github/CODEOWNERS", ".github/PULL_REQUEST_TEMPLATE.md", ".github/ISSUE_TEMPLATE/config.yml",
                     ".github/ISSUE_TEMPLATE/bug_report.yml", ".github/ISSUE_TEMPLATE/feature_request.yml",
                     "CONTRIBUTING.md", "SECURITY.md", "CHANGELOG.md", "README.md"] {
            #expect(Repo.exists(path), "\(path) is missing")
        }
    }
}
