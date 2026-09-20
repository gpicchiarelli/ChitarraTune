import Foundation
import Testing

/// ADR 0001: every architecture decision record is well-formed, indexed and enforced by something
/// that exists.
@Suite("Architecture decision records")
struct ADRPolicyTests {
    static let directory = "docs/adr"
    static let sections = ["## Context", "## Decision", "## Consequences", "## Enforcement"]
    /// The index and the blank a new record is copied from: neither is a decision.
    static let notRecords: Set = ["README.md", "0000-template.md"]

    static var records: [URL] {
        Repo.files(in: directory, extensions: ["md"]).filter { !notRecords.contains($0.lastPathComponent) }
    }

    @Test("Records are numbered consecutively from 0001 and named NNNN-kebab-title.md")
    func numbering() throws {
        let names = Self.records.map(\.lastPathComponent)
        #expect(names.count >= 11, "the decisions of ADR 0002–0011 must stay recorded")
        for (offset, name) in names.enumerated() {
            #expect(name.hasPrefix(String(format: "%04d-", offset + 1)), "\(name) breaks the numbering")
            #expect(name.wholeMatch(of: /\d{4}-[a-z0-9]+(-[a-z0-9]+)*\.md/) != nil, "\(name) is not NNNN-kebab-title.md")
        }
    }

    @Test("The index lists every record, and nothing else")
    func index() throws {
        let index = try Repo.text("\(Self.directory)/README.md")
        let linked = index.matches(of: /\]\((\d{4}-[^)]+\.md)\)/)
            .map { String($0.output.1) }
            .filter { !Self.notRecords.contains($0) }
        #expect(linked == Self.records.map(\.lastPathComponent))
    }

    @Test("Every record has a title, a status and the four sections in order", arguments: records)
    func structure(record: URL) throws {
        let text = try String(contentsOf: record, encoding: .utf8)
        let number = String(record.lastPathComponent.prefix(4))
        #expect(text.hasPrefix("# ADR \(number): "), "title must start with “# ADR \(number): ”")
        #expect(text.contains(/\nStatus: (Accepted \(\d{4}-\d{2}-\d{2}\)|Superseded by ADR \d{4})\n/), "missing or malformed status line")
        let positions = Self.sections.map { text.range(of: "\n\($0)\n")?.lowerBound }
        #expect(positions.allSatisfy { $0 != nil }, "missing one of \(Self.sections)")
        let found = positions.compactMap(\.self)
        #expect(found == found.sorted(), "sections out of order")
        #expect(text.contains("\n1. "), "the decision must be numbered rules")
    }

    /// The rules are cited by number, in the code and in other records ("ADR 0008 rule 6"), so a rule
    /// appended in the wrong place silently moves what every citation of it points at.
    @Test("The decision's rules are numbered 1, 2, 3 … in that order", arguments: records)
    func ruleNumbering(record: URL) throws {
        let text = try String(contentsOf: record, encoding: .utf8)
        let afterHeading = try #require(text.components(separatedBy: "\n## Decision\n").last)
        let decision = try #require(afterHeading.components(separatedBy: "\n## ").first)
        let numbers = decision.matches(of: /\n(\d+)\.[ ]/).compactMap { Int($0.output.1) }
        try #require(!numbers.isEmpty, "\(record.lastPathComponent): the decision must be numbered rules")
        #expect(numbers == Array(1...numbers.count), "\(record.lastPathComponent): rules run \(numbers)")
    }

    /// A new record is copied from the template, so the template must show exactly the shape the
    /// tests above demand — otherwise the first thing a contributor copies is already wrong.
    @Test("The template shows the four sections, in order, and is not listed as a decision")
    func template() throws {
        let text = try Repo.text("\(Self.directory)/0000-template.md")
        #expect(text.hasPrefix("# ADR 0000: "))
        #expect(text.contains("\nStatus: Template\n"), "the template must not claim a status a record could have")
        let positions = Self.sections.map { text.range(of: "\n\($0)\n")?.lowerBound }
        #expect(positions.allSatisfy { $0 != nil }, "the template is missing one of \(Self.sections)")
        #expect(positions.compactMap(\.self) == positions.compactMap(\.self).sorted(), "sections out of order")
        #expect(text.contains("\n1. "), "the template must show numbered rules")
        #expect(try Repo.text("\(Self.directory)/README.md").contains("0000-template.md"), "the index must point at the template")
    }

    @Test("Every record is enforced by files that exist", arguments: records)
    func enforcement(record: URL) throws {
        let text = try String(contentsOf: record, encoding: .utf8)
        let section = try #require(text.components(separatedBy: "\n## Enforcement\n").last)
        let paths = section.matches(of: /`([A-Za-z0-9_.\-]+(\/[A-Za-z0-9_.+\-]+)+)`/).map { String($0.output.1) }
        #expect(!paths.isEmpty, "an ADR without enforcement is not a decision")
        for path in paths {
            #expect(Repo.exists(path), "\(record.lastPathComponent) names \(path), which does not exist")
        }
    }
}
