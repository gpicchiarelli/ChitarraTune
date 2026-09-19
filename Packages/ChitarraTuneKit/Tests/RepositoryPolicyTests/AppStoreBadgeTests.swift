import Foundation
import Testing

/// Apple's App Store marketing guidelines, applied to the README: only Apple's own badge artwork, in
/// the language of the text around it, at least 40 points high, always a link to the app's product
/// page, and only once the app is available. `Scripts/app-store-badges.sh` is what writes them.
@Suite("App Store badges follow Apple's marketing guidelines")
struct AppStoreBadgeTests {
    private struct Section {
        let language: String
        let locale: String
        let storefront: String
        let names: [String]
    }

    private static let sections = [
        Section(language: "en", locale: "en-us", storefront: "", names: ["Download on the App Store", "Download on the Mac App Store"]),
        Section(language: "it", locale: "it-it", storefront: "it/", names: ["Scarica su App Store", "Scarica su Mac App Store"]),
    ]
    private static let badges = ["download-on-the-app-store", "download-on-the-mac-app-store"]
    private static let toolbox = "https://toolbox.marketingtools.apple.com/api/v2/badges/"

    /// Checks the badge blocks of a README and returns the App Store IDs they link to: none before release.
    private static func audit(_ readme: String) throws -> Set<String> {
        var outside = readme
        var ids = Set<String>()
        var filled = 0
        for section in sections {
            let start = "<!-- app-store-badges:\(section.language):start -->"
            let end = "<!-- app-store-badges:\(section.language):end -->"
            #expect(readme.components(separatedBy: start).count == 2, "the README needs exactly one \(start)")
            let opening = try #require(readme.range(of: start))
            let closing = try #require(readme.range(of: end, range: opening.upperBound..<readme.endIndex))
            let content = String(readme[opening.upperBound..<closing.lowerBound])
            outside = outside.replacingOccurrences(of: start + content + end, with: "")

            let links = content.matches(of: /<a href="([^"]+)"><img alt="([^"]+)" src="([^"]+)" height="(\d+)"><\/a>/)
            guard content.contains("<img") || content.contains("<a ") else {
                #expect(content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<!--"), "an empty \(section.language) block holds only a comment")
                continue
            }
            filled += 1
            #expect(links.count == 2 && content.components(separatedBy: "<img").count == 3,
                    "the \(section.language) block holds the App Store and Mac App Store badges, each inside its link")
            for (link, (name, badge)) in zip(links, zip(section.names, badges)) {
                let (_, href, alt, source, height) = link.output
                #expect(source == toolbox + badge + "/black/" + section.locale, "\(source) is not Apple's \(section.locale) \(badge) badge")
                #expect(alt == name)
                #expect((Int(height) ?? 0) >= 40, "Apple's minimum badge height on screen is 40 points")
                let page = "https://apps.apple.com/\(section.storefront)app/id"
                #expect(href.hasPrefix(page), "\(href) is not the product page on the \(section.language) storefront")
                let id = String(href.dropFirst(page.count))
                #expect(id.wholeMatch(of: /\d{6,12}/) != nil, "\(href) is not a product page")
                ids.insert(id)
            }
        }
        #expect(filled == 0 || filled == sections.count, "both languages get the badges, or neither does")
        #expect(ids.count <= 1, "every badge links to the same app")
        let strayLinks = outside.contains("marketingtools.apple.com") || outside.contains("apps.apple.com")
        let homeMade = outside.contains(/alt="[^"]*App Store/)
        #expect(!strayLinks, "App Store badges and links live only in the blocks that Scripts/app-store-badges.sh writes")
        #expect(!homeMade, "no home-made App Store badge")
        return ids
    }

    private static func runScript(_ arguments: [String], readme: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [Repo.url("Scripts/app-store-badges.sh").path] + arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["README": readme.path]) { $1 }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    @Test("The README's badges are Apple's, localized, linked to the product page, and credited")
    func readme() throws {
        let readme = try Repo.text("README.md")
        _ = try Self.audit(readme)
        let english = try #require(readme.range(of: "<!-- app-store-badges:en:start -->"))
        let italian = try #require(readme.range(of: "<!-- app-store-badges:it:start -->"))
        #expect(english.lowerBound < (readme.range(of: "\n## Features")?.lowerBound ?? readme.startIndex), "the English badges belong in the header")
        #expect(italian.lowerBound > (readme.range(of: "\n## Italiano")?.lowerBound ?? readme.endIndex), "the Italian badges belong in the Italian section")
        #expect(readme.contains("App Store and Mac App Store are service marks of Apple Inc."), "Apple's credit line for the badges")
    }

    @Test("The script adds the badges and takes them out again, touching nothing else")
    func script() throws {
        let original = try Repo.text("README.md")
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("README-\(UUID().uuidString).md")
        try original.write(to: copy, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: copy) }

        #expect(try Self.runScript(["12ab"], readme: copy) != 0, "an App Store ID is digits only")
        #expect(try Self.runScript(["1234567890", "--skip-availability-check"], readme: copy) == 0)
        #expect(try Self.audit(String(contentsOf: copy, encoding: .utf8)) == ["1234567890"])
        #expect(try Self.runScript(["--remove"], readme: copy) == 0)
        let emptied = try String(contentsOf: copy, encoding: .utf8)
        #expect(try Self.audit(emptied).isEmpty)
        if try Self.audit(original).isEmpty { #expect(emptied == original) }
    }
}
