import Foundation
import Testing

/// The App Store listing in `AppStore/metadata`, checked against App Store Connect's limits and
/// App Review guidelines before it is ever pasted into App Store Connect.
@Suite("App Store metadata")
struct AppStoreMetadataTests {
    static let locales = ["en-US", "it"]

    /// App Store Connect field limits, in characters.
    static let limits: [String: Int] = [
        "name.txt": 30, "subtitle.txt": 30, "promotional_text.txt": 170, "keywords.txt": 100,
        "description.txt": 4_000, "release_notes.txt": 4_000,
    ]

    static func field(_ locale: String, _ file: String) throws -> String {
        try Repo.text("AppStore/metadata/\(locale)/\(file)").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("Every field exists in English and Italian, within App Store Connect's limits", arguments: locales)
    func limits(locale: String) throws {
        for (file, limit) in Self.limits {
            let text = try Self.field(locale, file)
            #expect(!text.isEmpty, "\(locale)/\(file) is empty")
            #expect(text.count <= limit, "\(locale)/\(file) has \(text.count) characters, the limit is \(limit)")
        }
    }

    @Test("Keywords are comma-separated, unique, and do not repeat the app name", arguments: locales)
    func keywords(locale: String) throws {
        let keywords = try Self.field(locale, "keywords.txt").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(keywords.allSatisfy { !$0.isEmpty })
        #expect(Set(keywords.map { $0.lowercased() }).count == keywords.count, "duplicate keywords")
        #expect(!keywords.contains { $0.lowercased().contains("chitarratune") }, "the name is indexed already; don't spend keywords on it")
    }

    @Test("The listing makes no claim App Review rejects", arguments: locales)
    func guidelines(locale: String) throws {
        let text = try Self.limits.keys.map { try Self.field(locale, $0) }.joined(separator: "\n").lowercased()
        // 2.3.10: no other platforms; 2.3.7: no prices or rankings in metadata; no placeholder text.
        for forbidden in ["android", "windows", "google play", "#1", "best tuner", "number one", "lorem", "todo", "tbd", "€", "$"] {
            #expect(!text.contains(forbidden), "\(locale): the metadata mentions '\(forbidden)'")
        }
        #expect(try Self.field(locale, "name.txt") == "ChitarraTune")
    }

    @Test("Support, privacy and marketing URLs are HTTPS and point at files that exist", arguments: locales)
    func urls(locale: String) throws {
        let repository = "https://github.com/gpicchiarelli/ChitarraTune"
        for file in ["support_url.txt", "privacy_url.txt", "marketing_url.txt"] {
            let url = try Self.field(locale, file)
            #expect(url.hasPrefix(repository), "\(locale)/\(file): \(url)")
            if let path = url.components(separatedBy: "/blob/main/").dropFirst().first {
                #expect(Repo.exists(path), "\(locale)/\(file) points at \(path), which does not exist")
            }
        }
        #expect(try Self.field(locale, "privacy_url.txt").hasSuffix("PRIVACY.md"))
        #expect(try Self.field(locale, "support_url.txt").hasSuffix("SUPPORT.md"))
    }

    @Test("The support page gives a way to reach a person, and the privacy policy matches the manifest")
    func pages() throws {
        let support = try Repo.text("SUPPORT.md")
        #expect(support.contains("mailto:"), "App Review requires a support URL with contact information")
        let privacy = try Repo.text("PRIVACY.md")
        #expect(privacy.contains("collects no data") && privacy.contains("non raccoglie alcun dato"))
        #expect(privacy.contains("never recorded") && privacy.contains("No network"))
    }

    @Test("App Review notes explain how to use the app without an account")
    func reviewNotes() throws {
        let notes = try Repo.text("AppStore/review/notes.txt")
        #expect(notes.contains("no account"))
        #expect(notes.contains("microphone"))
    }

    /// The app's language is a launch argument, which never reaches the system's own status bar. An
    /// iPad shows the date up there, so the English screenshots were delivered reading "Dom 20 set",
    /// and the clock was on the Italian 24-hour format in both languages. The device's own language
    /// has to be set as well, and it is only read when the device boots.
    @Test("The screenshot tool gives the simulator the language of the screenshots it is taking")
    func screenshotLanguage() throws {
        let script = try Repo.text("Scripts/screenshots.sh")
        #expect(script.contains("AppleLanguages") && script.contains("AppleLocale"),
                "the simulator's own language must follow the screenshot language")
        #expect(script.contains("simctl shutdown"), "the language is only read at boot")
        for device in ["$IPHONE", "$IPAD"] {
            #expect(script.contains("prepare_simulator \"\(device)\" \"$language\""),
                    "\(device) must be prepared for the language being shot")
        }
    }
}
