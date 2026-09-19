import Foundation
import Testing
import TunerCore

/// The documentation is the specification. These tests fail when it and the code disagree.
@Suite("Documentation matches the implementation")
struct DocumentationSpecTests {
    @Test("The README's tuning table is exactly the tuning catalog")
    func readmeTunings() throws {
        let readme = try Repo.text("README.md")
        let section = try #require(readme.components(separatedBy: "## Tunings").dropFirst().first?.components(separatedBy: "\n## ").first)
        let rows: [[String]] = section.split(separator: "\n")
            .filter { $0.hasPrefix("| ") && $0.range(of: #"^\|[\s:|-]+\|$"#, options: .regularExpression) == nil && !$0.contains("Strings, low to high") }
            .map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
        #expect(rows.count == Tuning.catalog.count, "README lists \(rows.count) tunings, the catalog has \(Tuning.catalog.count)")
        for (row, tuning) in zip(rows, Tuning.catalog) {
            let notes = row.last?.components(separatedBy: " · ") ?? []
            #expect(notes == tuning.strings.map { $0.name() }, "README row '\(row.first ?? "")' differs from \(tuning.id)")
        }
    }

    @Test("Documents quote the engine numbers that the code really uses")
    func architectureNumbers() throws {
        let architecture = try Repo.text("docs/ARCHITECTURE.md")
        let p = EngineParameters.standard
        for expected in ["\(p.gateOpenLevel)", "\(p.gateCloseLevel)", "\(p.minimumGateLevel)", "\(Int(p.gateNoiseMargin))×", "\(Int(p.noiseFloorRise)) dB per second", "\(p.minimumClarity)", "±\(Int(p.maximumDeviation)) cents",
                         "±\(Int(p.inTuneThreshold)) cents", "\(Int(p.inTuneExitMargin)) cents of exit margin", "\(p.holdDuration) s",
                         "25 ms", "45 ms", "0.7×–1.5×"] {
            #expect(architecture.contains(expected), "ARCHITECTURE.md no longer mentions '\(expected)'")
        }
        let readme = try Repo.text("README.md")
        #expect(readme.contains("415") && readme.contains("466"))
        #expect(readme.contains("±5 cents"))
    }

    @Test("Every Siri and Shortcuts action the README lists is implemented, and no other")
    func intents() throws {
        let source = try Repo.text("App/Intents/TunerIntents.swift") + Repo.text("Shared/StartTuningIntent.swift")
        let implemented = Set(
            try NSRegularExpression(pattern: #"struct (\w+): AppIntent"#)
                .matches(in: source, range: NSRange(source.startIndex..., in: source))
                .compactMap { Range($0.range(at: 1), in: source).map { String(source[$0]) } }
        )
        #expect(implemented == ["StartTuningIntent", "StopTuningIntent", "SetTuningIntent", "SetReferencePitchIntent", "PickStringIntent", "ChooseInputIntent"])
        let readme = try Repo.text("README.md")
        for action in ["Start tuning", "Stop tuning", "Set tuning", "Set reference pitch", "Pick a string", "Choose input"] {
            #expect(readme.contains("**\(action)**"), "README no longer documents '\(action)'")
        }
        #expect(source.contains("static let supportedModes: IntentModes = .foreground"), "Start must open the app: a microphone needs the foreground")
        #expect(!source.contains("openAppWhenRun"), "openAppWhenRun is deprecated since iOS and macOS 26: use supportedModes")
    }

    @Test("The keyboard shortcuts in the README exist in the menu commands")
    func shortcuts() throws {
        let commands = try Repo.text("App/Tuner/TunerCommands.swift")
        for shortcut in [#".keyboardShortcut("l")"#, #".keyboardShortcut("0")"#, #".keyboardShortcut("n")"#, "KeyEquivalent(Character(\"\\(number)\"))"] {
            #expect(commands.contains(shortcut), "TunerCommands.swift lost \(shortcut)")
        }
        #expect(commands.contains("ForEach(1...(tuner?.tuning.stringCount"), "the string menu must follow the tuning, not a fixed six")
        #expect(try Repo.text("App/ChitarraTuneApp.swift").contains("Settings {"), "⌘, needs a Settings scene")
    }

    @Test("Each platform behaviour claimed in docs/ACCESSIBILITY.md has code behind it")
    func accessibilityClaims() throws {
        let sources = Repo.files(in: "App", extensions: ["swift"]) + Repo.files(in: "Shared", extensions: ["swift"])
        let app = try sources.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        for evidence in ["accessibilityReduceMotion", "AccessibilityNotification.Announcement", ".updatesFrequently",
                         "accessibilityHint", ".isSelected", "accessibilityValue", "accessibilityLabel", "sensoryFeedback",
                         "dynamicTypeSize"] {
            #expect(app.contains(evidence), "docs/ACCESSIBILITY.md claims support that the code no longer has: \(evidence)")
        }
    }

    @Test("Relative links in the Markdown files all resolve")
    func links() throws {
        let files = ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "SECURITY.md", "PRIVACY.md", "CONTRIBUTORS.md", "PLATFORMS.md",
                     "CODE_SIGNING.md", "APPLE_COMPLIANCE.md", "SUPPORT.md", "docs/ARCHITECTURE.md", "docs/ACCESSIBILITY.md",
                     "docs/DEVICE_TEST_PLAN.md", "AppStore/README.md", "Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md",
                     ".github/PULL_REQUEST_TEMPLATE.md"]
        let link = try NSRegularExpression(pattern: ##"\]\(([^)#\s]+)(?:#[^)]*)?\)|(?:src|href)="([^"#]+)""##)
        for file in files {
            let text = try Repo.text(file)
            let base = Repo.url(file).deletingLastPathComponent()
            for match in link.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let target = (1...2).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }.first ?? ""
                guard !target.isEmpty, !target.hasPrefix("http"), !target.hasPrefix("mailto:") else { continue }
                #expect(FileManager.default.fileExists(atPath: base.appendingPathComponent(target).standardized.path), "\(file): broken link '\(target)'")
            }
        }
    }

    @Test("The platform table in PLATFORMS.md matches the build settings")
    func platforms() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        #expect(s["MACOSX_DEPLOYMENT_TARGET"] == "26.0" && s["IPHONEOS_DEPLOYMENT_TARGET"] == "26.0")
        #expect(s["TARGETED_DEVICE_FAMILY"] == "1,2", "iPhone and iPad only")
        #expect(s["SUPPORTS_MACCATALYST"] == "NO")
        #expect(s["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] == "NO" && s["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] == "NO")
        #expect(s["PRODUCT_BUNDLE_IDENTIFIER"] == "com.chitarratune.app")
        let iPhone = try #require(s["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"]).split(separator: " ")
        let iPad = try #require(s["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"]).split(separator: " ")
        #expect(iPhone.count == 3 && !iPhone.contains("UIInterfaceOrientationPortraitUpsideDown"), "iPhone: portrait and both landscapes")
        #expect(iPad.count == 4, "iPad: all four orientations")
    }

    @Test("The changelog keeps an Unreleased section and the version badge matches the build settings")
    func versioning() throws {
        #expect(try Repo.text("CHANGELOG.md").contains("## [Unreleased]"))
        let version = try #require(try Repo.xcconfig("Config/Base.xcconfig")["MARKETING_VERSION"])
        #expect(try Repo.text("README.md").contains("version-\(version)-"), "README version badge is not \(version)")
    }
}
