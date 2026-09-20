import Foundation
import Testing

/// ADR 0015: the user guide is written once, in English and Italian, and ships in the Mac app as an
/// Apple Help Book that matches it exactly, opened from the Help menu, and never goes online.
@Suite("User guide")
struct UserGuideTests {
    static let languages = ["en", "it"]

    @Test("The Help Book in the repository is exactly what the guide produces")
    func bookMatchesGuide() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", Repo.url("Scripts/build-help.py").path, "--check"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let message = String(bytes: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(process.terminationStatus == 0, "\(message)")
    }

    @Test("Every page exists in both languages, with a title and a description", arguments: languages)
    func pages(language: String) throws {
        let english = Set(Repo.files(in: "docs/guide/en", extensions: ["md"]).map(\.lastPathComponent))
        let pages = Repo.files(in: "docs/guide/\(language)", extensions: ["md"])
        #expect(Set(pages.map(\.lastPathComponent)) == english, "\(language) and en have different pages")
        #expect(pages.count >= 15)
        for page in pages {
            let lines = try String(contentsOf: page, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            #expect(lines.first?.hasPrefix("# ") == true, "\(page.lastPathComponent): no title")
            #expect(lines.dropFirst().first?.hasPrefix("<!-- description: ") == true, "\(page.lastPathComponent): no description")
        }
    }

    @Test("The guide and the book never reach the network")
    func offline() throws {
        for language in Self.languages {
            for page in Repo.files(in: "docs/guide/\(language)", extensions: ["md"]) {
                let text = try String(contentsOf: page, encoding: .utf8)
                #expect(!text.contains("](http"), "\(language)/\(page.lastPathComponent) links outside the book")
            }
            for page in Repo.files(in: "Help/ChitarraTune.help/Contents/Resources/\(language).lproj", extensions: ["html"]) {
                let text = try String(contentsOf: page, encoding: .utf8)
                #expect(!text.contains("src=\"http") && !text.contains("href=\"http"), "\(page.lastPathComponent) loads from the network")
            }
        }
        let info = try Repo.plist("Help/ChitarraTune.help/Contents/Info.plist")
        #expect(info["HPDBookKBURL"] == nil && info["HPDBookRemoteURL"] == nil, "the Help Book must not fetch remote content")
    }

    @Test("The Mac app ships the book, names it, and opens it from the Help menu")
    func wiring() throws {
        let book = try Repo.plist("Help/ChitarraTune.help/Contents/Info.plist")
        let app = try Repo.plist("Config/Info.plist")
        #expect(app["CFBundleHelpBookFolder"] as? String == "ChitarraTune.help")
        #expect(app["CFBundleHelpBookName"] as? String == book["CFBundleIdentifier"] as? String)
        #expect(book["HPDBookType"] as? String == "3" && book["HPDBookAccessPath"] as? String == "index.html")

        let project = try Repo.text("ChitarraTune.xcodeproj/project.pbxproj")
        let buildFile = "/* ChitarraTune.help in Resources */ = {isa = PBXBuildFile; "
            + "fileRef = F00000000000000000000010 /* ChitarraTune.help */; platformFilters = (macos, ); };"
        #expect(project.contains(buildFile), "the book ships in the Mac app only")
        #expect(project.contains("path = Help/ChitarraTune.help;"))

        let commands = try Repo.text("App/Tuner/TunerCommands.swift")
        #expect(commands.contains("NSApp.showHelp(nil)") && commands.contains(#".keyboardShortcut("?", modifiers: .command)"#))
        #expect(try Repo.text("App/Settings/SettingsView.swift").contains("docs/guide/\\(language)/index.md"),
                "iPhone and iPad link to the same guide")
    }
}
