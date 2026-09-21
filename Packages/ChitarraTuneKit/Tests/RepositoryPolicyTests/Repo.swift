import Foundation

/// Read-only access to the repository the tests live in.
enum Repo {
    /// `<root>/Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/Repo.swift` → `<root>`.
    static let root: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }()

    static func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    static func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: url(path).path) }

    static func text(_ path: String) throws -> String { try String(contentsOf: url(path), encoding: .utf8) }

    /// Files below `directory` (relative to the root) with one of the extensions.
    static func files(in directory: String, extensions: Set<String>) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: url(directory), includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { extensions.contains($0.pathExtension) && !$0.path.contains("/.build/") }
            .sorted { $0.path < $1.path }
    }

    static func relativePath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    /// Merged build settings of the given `.xcconfig` files (later files win), with `#include` and
    /// `#include?` followed in place, the way `xcodebuild` reads them. Keys keep any `[sdk=…]`
    /// condition verbatim.
    ///
    /// The includes are the point. `Config/Base.xcconfig` ends with `#include? "Local.xcconfig"`, a
    /// gitignored file for whoever is working; reading only the tracked files meant a `Local.xcconfig`
    /// that turned the App Sandbox off left every policy test certifying a configuration the build no
    /// longer had. These tests exist to close the gap between what the repository says and what it
    /// builds, so they read what the build reads.
    static func xcconfig(_ paths: String...) throws -> [String: String] {
        var settings: [String: String] = [:]
        for path in paths { try merge(url(path), into: &settings) }
        return settings
    }

    private static func merge(_ file: URL, into settings: inout [String: String]) throws {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return }
        for raw in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = stripComment(String(raw))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#include") {
                // `#include "X"` must exist; `#include? "X"` may be absent, which `merge` allows for both.
                guard let open = trimmed.firstIndex(of: "\""),
                      let close = trimmed.lastIndex(of: "\""), open < close else { continue }
                let relative = String(trimmed[trimmed.index(after: open)..<close])
                try merge(file.deletingLastPathComponent().appendingPathComponent(relative), into: &settings)
                continue
            }
            guard !trimmed.hasPrefix("#"), let equals = line.range(of: " = ") else { continue }
            settings[line[..<equals.lowerBound].trimmingCharacters(in: .whitespaces)]
                = String(line[equals.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
    }

    /// Removes an `//` comment. Only at the start of the line or after whitespace: a setting whose
    /// value is a URL carries `//` in the middle of a word, and cutting there would silently truncate
    /// it to `https:`.
    private static func stripComment(_ line: String) -> String {
        var index = line.startIndex
        while let found = line.range(of: "//", range: index..<line.endIndex) {
            let before = found.lowerBound == line.startIndex ? nil : line[line.index(before: found.lowerBound)]
            if before == nil || before?.isWhitespace == true { return String(line[..<found.lowerBound]) }
            index = found.upperBound
        }
        return line
    }

    static func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: url(path))
        return try (PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]) ?? [:]
    }
}
