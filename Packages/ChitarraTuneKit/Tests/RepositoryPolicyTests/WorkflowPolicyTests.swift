import Foundation
import Testing

/// Supply-chain rules for `.github/workflows`, enforced on every change to them.
@Suite("Workflow policy")
struct WorkflowPolicyTests {
    private var workflows: [URL] { Repo.files(in: ".github/workflows", extensions: ["yml", "yaml"]) }

    private func lines(_ file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
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
