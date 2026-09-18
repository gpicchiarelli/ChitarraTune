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

    /// Merged build settings of the given `.xcconfig` files (later files win). Keys keep any
    /// `[sdk=…]` condition verbatim.
    static func xcconfig(_ paths: String...) throws -> [String: String] {
        var settings: [String: String] = [:]
        for path in paths {
            for raw in try text(path).split(separator: "\n", omittingEmptySubsequences: true) {
                var line = String(raw)
                if let comment = line.range(of: "//") { line = String(line[..<comment.lowerBound]) }
                guard !line.hasPrefix("#"), let equals = line.range(of: " = ") else { continue }
                let key = line[..<equals.lowerBound].trimmingCharacters(in: .whitespaces)
                let value = line[equals.upperBound...].trimmingCharacters(in: .whitespaces)
                settings[key] = value
            }
        }
        return settings
    }

    static func plist(_ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: url(path))
        return try (PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]) ?? [:]
    }
}
