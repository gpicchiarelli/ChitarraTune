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
        let files = (workflows + Repo.files(in: ".github/ISSUE_TEMPLATE", extensions: ["yml"])
            + [Repo.url(".github/dependabot.yml"), Repo.url(".github/actionlint.yaml")]).map(\.path)
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
        // Lines that *declare* one, not every mention: a comment naming `runs-on:` is prose.
        func declarations(_ lines: [String], of key: String) -> Int {
            lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }.count
        }
        for file in workflows {
            let text = try String(contentsOf: file, encoding: .utf8)
            let all = try lines(file)
            let jobs = declarations(all, of: "runs-on")
            #expect(declarations(all, of: "timeout-minutes") == jobs, "\(file.lastPathComponent): job without timeout")
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
        // The four slices the app ships in. Each is built by exactly one job, and the job that
        // builds it also checks something a bare compile would not: macOS Release by the release
        // check, iOS Release by the pointer-authentication check, and the two Debug slices by the
        // UI tests they carry. A job that only repeats one of these builds is weight, not cover.
        for destination in ["generic/platform=iOS", "generic/platform=iOS Simulator", "platform=macOS"] {
            #expect(ci.contains(destination), "no job builds for \(destination)")
        }
        #expect(ci.contains("run: Scripts/release-check.sh"), "every push must build and check the Mac app as a release (ADR 0013)")
        #expect(ci.contains("gate:"), "ci.yml needs the aggregate 'gate' job that branch protection requires")
        #expect(ci.contains("needs: [lint, kit, app, dsp, release, ui-ios, ui-mac]"), "the gate must wait for every job")
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

    /// ADR 0017 rule 5. An unnamed `swift build` writes into the working tree, and a workflow step is
    /// what people and agents copy their commands from: these two lines put 211 MB of iCloud-synced
    /// build output under `Packages/ChitarraTuneKit/.build` on a real machine.
    @Test("Every package build in a workflow names where it builds")
    func namedScratchPath() throws {
        for file in workflows {
            for line in try lines(file) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("#"), trimmed.contains("swift build") || trimmed.contains("swift test") else { continue }
                #expect(trimmed.contains("--scratch-path"),
                        "\(file.lastPathComponent): '\(trimmed)' builds wherever it happens to be run (ADR 0017 rule 5)")
            }
        }
    }

    /// ADR 0018 rules 2 and 5: CI builds the package with the flags the local gate uses, and the full
    /// accuracy matrix keeps a runner to itself — a real-time budget measured beside a saturated test
    /// suite measures the suite, not the budget.
    @Test("CI compiles the package like the local gate, and the accuracy matrix keeps its own job")
    func optimisedKitJob() throws {
        let ci = try Repo.text(".github/workflows/ci.yml")
        for flag in ["-c release", "-Xswiftc -enable-testing", "-Xswiftc -warnings-as-errors"] {
            #expect(ci.contains(flag), "the kit job must build with \(flag), as Scripts/verify.sh does (ADR 0018 rule 2)")
        }
        #expect(ci.contains("CHITARRA_FULL_DSP"), "the full accuracy matrix must still run (ADR 0008)")
        #expect(ci.contains("dsp:"), "the accuracy matrix and the real-time budgets need a job of their own (ADR 0018 rule 5)")
    }

    /// Regression, and it cost a red gate: `continue-on-error: ${{ matrix.allowFailure == true }}`
    /// never evaluated true, so the one job documented as unable to stop the gate stopped it
    /// (run 35514845091). Actions compares a matrix scalar and a boolean literal by casting both to
    /// numbers, and a string casts to NaN. Whether a step may fail is not a thing to compute.
    @Test("`continue-on-error` is a literal, never an expression")
    func literalContinueOnError() throws {
        for file in workflows {
            for line in try lines(file) where line.contains("continue-on-error:") {
                let value = line.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                #expect(value == "true" || value == "false",
                        "\(file.lastPathComponent): continue-on-error must be written out, not computed: '\(value)'")
            }
        }
    }

    /// ADR 0019: the shell that builds, signs and publishes the product is read by something that
    /// does not get tired. Both linters are pinned and checksum-verified, because a linter runs with
    /// the job's full permissions — it is supply chain like every action pinned to a commit.
    @Test("The gate lints the shell and the workflows, with linters it has verified")
    func shellAndWorkflowsAreLinted() throws {
        let ci = try Repo.text(".github/workflows/ci.yml")
        #expect(ci.contains("  lint:"), "ci.yml needs the lint job (ADR 0019 rule 1)")
        #expect(ci.contains("run: actionlint") && ci.contains("shellcheck -x --severity=warning"),
                "both linters must run, at the agreed severity (ADR 0019 rules 1 and 2)")
        #expect(ci.components(separatedBy: "sha256sum --check --strict").count - 1 >= 1,
                "a downloaded linter must be refused unless its checksum matches (ADR 0019 rule 4)")
        // A regex literal does not interpolate, so this one is built at runtime.
        for tool in ["ACTIONLINT_SHA", "SHELLCHECK_SHA"] {
            let recorded = try Regex("\(tool): [0-9a-f]{64}")
            #expect(ci.firstMatch(of: recorded) != nil, "\(tool) is not recorded as a SHA-256")
        }
        #expect(Repo.exists(".github/actionlint.yaml"), "the runner label actionlint does not know is declared, not silenced")
    }

    /// ADR 0019 rule 3. Two of these sat in `ci.yml` for a linter this project did not run: a comment
    /// wearing the clothes of a control.
    @Test("A shellcheck directive names a rule and says why")
    func justifiedDirectives() throws {
        for file in workflows {
            let all = try lines(file)
            // A directive is a comment line of its own, before the command it covers. Prose that
            // merely mentions one — as the note above the lint job does — is not a directive.
            for (number, line) in all.enumerated()
            where line.trimmingCharacters(in: .whitespaces).hasPrefix("# shellcheck disable=") {
                #expect(try #/shellcheck disable=SC\d+/#.firstMatch(in: line) != nil,
                        "\(file.lastPathComponent):\(number + 1): a directive must name the rule it turns off")
                let reason = all[max(0, number - 2)..<number].contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
                #expect(reason, "\(file.lastPathComponent):\(number + 1): say why the rule does not apply")
            }
        }
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
                     ".github/ISSUE_TEMPLATE/release.yml",
                     "CONTRIBUTING.md", "SECURITY.md", "CHANGELOG.md", "README.md", "CODE_OF_CONDUCT.md"] {
            #expect(Repo.exists(path), "\(path) is missing")
        }
    }
}
