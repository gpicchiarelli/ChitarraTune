import Foundation
import Testing

/// English and Italian must be complete and consistent in every string catalog.
@Suite("Localization")
struct LocalizationTests {
    private static let catalogs = ["App/Resources/Localizable.xcstrings", "App/Resources/InfoPlist.xcstrings", "App/Resources/AppShortcuts.xcstrings"]

    /// All translated values of one localization, including plural and device variations.
    private func values(_ node: Any) -> [String] {
        guard let dictionary = node as? [String: Any] else { return [] }
        var found: [String] = []
        if let unit = dictionary["stringUnit"] as? [String: Any], let value = unit["value"] as? String { found.append(value) }
        if let variations = dictionary["variations"] as? [String: Any] {
            for group in variations.values { for entry in (group as? [String: Any] ?? [:]).values { found += values(entry) } }
        }
        return found
    }

    private func states(_ node: Any) -> [String] {
        guard let dictionary = node as? [String: Any] else { return [] }
        var found: [String] = []
        if let unit = dictionary["stringUnit"] as? [String: Any], let state = unit["state"] as? String { found.append(state) }
        if let variations = dictionary["variations"] as? [String: Any] {
            for group in variations.values { for entry in (group as? [String: Any] ?? [:]).values { found += states(entry) } }
        }
        return found
    }

    private func catalog(_ path: String) throws -> (source: String, strings: [String: [String: Any]]) {
        let data = try Data(contentsOf: Repo.url(path))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        return (root["sourceLanguage"] as? String ?? "", strings)
    }

    /// Format specifiers and `${placeholders}`, without positional indices, sorted.
    private func placeholders(_ text: String) throws -> [String] {
        let pattern = #"%(?:\d+\$)?(?:ll|l|hh|h)?[@dfsuxXcCi]|\$\{[A-Za-z]+\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]).replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression) }
            .sorted()
    }

    @Test("Source language is English", arguments: catalogs)
    func sourceLanguage(path: String) throws {
        #expect(try catalog(path).source == "en")
    }

    @Test("Every string exists in English and Italian, translated and non-empty", arguments: catalogs)
    func complete(path: String) throws {
        let (_, strings) = try catalog(path)
        #expect(!strings.isEmpty)
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            // A catalog keyed by its English text (App Shortcuts) needs no explicit "en".
            for language in ["en", "it"] where !(language == "en" && localizations["en"] == nil && path.hasSuffix("AppShortcuts.xcstrings")) {
                let node = try #require(localizations[language], "\(path): '\(key)' has no \(language) translation")
                #expect(states(node).allSatisfy { $0 == "translated" }, "\(path): '\(key)' [\(language)] is not marked translated")
                #expect(values(node).allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "\(path): '\(key)' [\(language)] is empty")
            }
        }
    }

    @Test("Placeholders and format specifiers agree between English and Italian", arguments: catalogs)
    func placeholdersMatch(path: String) throws {
        let (_, strings) = try catalog(path)
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let english = localizations["en"].map(values) ?? [key]
            let italian = localizations["it"].map(values) ?? []
            let expected = try Set(english.map(placeholders))
            for value in italian {
                #expect(try expected.contains(placeholders(value)), "\(path): '\(key)' — Italian '\(value)' has different placeholders than English")
            }
        }
    }

    @Test("The microphone permission text is translated")
    func permissionText() throws {
        let (_, strings) = try catalog("App/Resources/InfoPlist.xcstrings")
        let entry = try #require(strings["NSMicrophoneUsageDescription"])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        #expect(localizations["en"] != nil && localizations["it"] != nil)
    }
}
