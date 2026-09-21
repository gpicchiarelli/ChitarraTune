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

        // ACCURACY.md states the same engine in the words a musician reads, so it is held to the
        // same code. Decibels are what the gate's amplitudes are worth: 20·log₁₀ of them.
        let accuracy = try Repo.text("docs/ACCURACY.md")
        let decibels = { (amplitude: Double) in Int((20 * log10(amplitude)).rounded()) }
        for expected in ["±\(Int(p.inTuneThreshold)) cents", "±\(Int(p.inTuneThreshold + p.inTuneExitMargin)) cents",
                         "\(Int(p.hopDuration * 1000)) ms", "45 ms", "±\(Int(p.maximumDeviation)) cents",
                         "\(decibels(p.gateNoiseMargin)) dB above the room's noise floor",
                         "−\(-decibels(p.minimumGateLevel)) and −\(-decibels(p.gateOpenLevel)) dBFS",
                         "\(PitchMath.referenceARange.lowerBound.formatted(.number.precision(.fractionLength(0)))) to \(PitchMath.referenceARange.upperBound.formatted(.number.precision(.fractionLength(0)))) Hz"] {
            #expect(accuracy.contains(expected), "docs/ACCURACY.md no longer promises '\(expected)'")
        }
        #expect(accuracy.contains("six consecutive") == (p.stableAnalysesRequired == 6), "stability is \(p.stableAnalysesRequired) analyses")
    }

    /// The guide's status table, the catalog and the code are one vocabulary, in both languages.
    /// They were three: `tuner.status.close` ("Almost there", "Quasi") was translated, named by the
    /// guide as one of four statuses, and shown by nothing — `.flat(.close)` and `.flat(.far)` had
    /// the same word and the same symbol and differed only in colour, which `docs/ACCESSIBILITY.md`
    /// and the guide's own tip both say never happens.
    @Test("The statuses the guide names are the statuses the app can show, in both languages")
    func statusVocabulary() throws {
        let data = try Data(contentsOf: Repo.url("App/Resources/Localizable.xcstrings"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        let keys = strings.keys.filter { $0.hasPrefix("tuner.status.") }.sorted()
        #expect(keys == ["tuner.status.close", "tuner.status.flat", "tuner.status.inTune", "tuner.status.sharp"])

        let appearance = try Repo.text("App/DesignSystem/TuneAppearance.swift")
        for key in keys {
            #expect(appearance.contains(".\(LocalizationTests.generatedSymbol(for: key))"),
                    "no tuning state ever shows \(key)")
        }
        for language in ["en", "it"] {
            let guide = try Repo.text("docs/guide/\(language)/read-display.md")
            for key in keys {
                let word = try #require(
                    ((strings[key]?["localizations"] as? [String: Any])?[language] as? [String: Any])
                        .flatMap { ($0["stringUnit"] as? [String: Any])?["value"] as? String },
                    "\(key) has no \(language) value")
                #expect(guide.contains(word), "docs/guide/\(language)/read-display.md does not name '\(word)'")
            }
        }
    }

    /// What is promised about cost is the ceiling the test enforces, never a measurement: a
    /// measurement belongs to a machine and a toolchain, and the documents carried two different ones
    /// for the same figure (0.7 % and 0.8 %) while the test measured a third.
    @Test("The real-time budget quoted in the documents is the one the test enforces")
    func realTimeCeiling() throws {
        let test = try Repo.text("Packages/ChitarraTuneKit/Tests/TunerCoreTests/RealTimeBudgetTests.swift")
        let ceiling = try #require(test.firstMatch(of: #/\n *static let ceiling = 0\.(\d+)\n/#)?.output.1)
        let percent = "\(Int(ceiling.prefix(2)) ?? 0) %"
        #expect(test.contains("#expect(fraction < Self.ceiling)"), "the ceiling must be what is asserted")
        // ADR 0018 rule 5: on a loaded machine a timing assertion measures the machine. The ceiling
        // is held in the job that has the runner to itself, and nowhere else.
        #expect(test.contains(#"if enforced { #expect(fraction < Self.ceiling) }"#)
                && test.contains(#"environment["CHITARRA_FULL_DSP"]"#),
                "the ceiling must only be enforced where the runner is unloaded (ADR 0018 rule 5)")
        for document in ["docs/ACCURACY.md", "Packages/ChitarraTuneKit/Sources/TunerCore/TuningEngine.swift"] {
            let text = try Repo.text(document)
            #expect(text.contains(percent), "\(document) does not quote the \(percent) ceiling")
            #expect(text.contains("RealTimeBudgetTests"), "\(document) must name where the number comes from")
        }
    }

    /// No document may date a promise to a release the changelog does not list. This started as the
    /// settings that "carry over from 1.x", three lines under "1.0.0 is the first release"; the same
    /// sweep then found the App Store "free (from 2.0)" sitting in the README's Install section,
    /// which is the line somebody reads before deciding whether the app is for them.
    @Test("No document dates a promise to a release that was never made")
    func noPhantomReleases() throws {
        let changelog = try Repo.text("CHANGELOG.md")
        let released = Set(changelog.matches(of: #/\n## \[(\d+\.\d+\.\d+)\]/#).map { String($0.output.1) })
        let documents = ["CHANGELOG.md", "README.md", "CONTRIBUTING.md", "SUPPORT.md",
                         "docs/ARCHITECTURE.md", "docs/PLATFORMS.md", "docs/ACCURACY.md"]
        for document in documents {
            let text = try Repo.text(document)
            #expect(text.firstMatch(of: #/\b\d+\.x\b/#) == nil, "\(document) names a whole release line that does not exist")
            // "from 2.0", "since v1.4": a version a sentence hangs a promise on. A bare number is
            // left alone — this repository is full of hertz and cents.
            for dated in text.matches(of: #/\b(?:from|since|as of)\s+v?(\d+\.\d+(?:\.\d+)?)\b/#) {
                let version = String(dated.output.1)
                let full = version.split(separator: ".").count == 3 ? version : version + ".0"
                #expect(released.contains(full),
                        "\(document) promises something from \(version), which CHANGELOG.md does not list")
            }
        }
    }

    /// DocC resolves a ``link`` only to a symbol it can see. A link to a `private` one renders as
    /// literal double backticks and warns on every documentation build.
    @Test("No documentation link points at a private symbol", arguments: ["Packages/ChitarraTuneKit/Sources", "App", "Shared", "Controls"])
    func documentationLinks(directory: String) throws {
        for file in Repo.files(in: directory, extensions: ["swift"]) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let hidden = Set(text.matches(of: #/private +(?:static +)?(?:var|let|func) +([A-Za-z_]\w*)/#)
                .map { String($0.output.1) })
            for link in text.matches(of: #/``([A-Za-z_]\w*)``/#) where hidden.contains(String(link.output.1)) {
                Issue.record("\(Repo.relativePath(file)) links to ``\(link.output.1)``, which is private there")
            }
        }
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
        for action in ["Start Tuning", "Stop Tuning", "Set Tuning", "Set Reference Pitch", "Pick String", "Choose Microphone"] {
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
        let files = Repo.files(in: ".", extensions: ["md"]).map(Repo.relativePath).filter { !$0.contains("/.build/") }
        #expect(files.count > 25, "found only \(files.count) Markdown files")
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

    /// `Config/Base.xcconfig` is the only place the minimum system version is written down. Everything
    /// else — the package manifest, the release check, the README in both languages, the platform
    /// table, the changelog — is held against it here, so raising it for a new yearly release means
    /// editing one number and being told what else to bring along, instead of hunting through eleven
    /// files and finding out from a store reviewer which one was missed.
    @Test("One minimum system version, and every file that states it agrees")
    func minimumSystemVersion() throws {
        let settings = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        let version = try #require(settings["MACOSX_DEPLOYMENT_TARGET"])
        #expect(settings["IPHONEOS_DEPLOYMENT_TARGET"] == version, "one minimum for every platform")
        let major = try #require(Int(version.prefix(while: { $0 != "." })), "\(version) does not start with a number")

        #expect(try Repo.text("Packages/ChitarraTuneKit/Package.swift").contains(".macOS(\"\(version)\")"))
        #expect(try Repo.text("Packages/ChitarraTuneKit/Package.swift").contains(".iOS(\"\(version)\")"))
        #expect(try Repo.text("Scripts/release-check.sh").contains("Config/Base.xcconfig"),
                "the release check must read the minimum, not repeat it")

        // A document states the version as an OS or as the Xcode that builds it; which of the two is
        // its own business, but it must say this one and must not still say last year's.
        func versions(_ major: Int) -> [String] {
            ["macOS \(major)", "iOS \(major)", "iPadOS \(major)", "Xcode \(major)"]
        }
        for document in ["README.md", "docs/PLATFORMS.md", "CHANGELOG.md", "CONTRIBUTING.md"] {
            let text = try Repo.text(document)
            #expect(versions(major).contains { text.contains($0) }, "\(document) never states \(major)")
            let stale = versions(major - 1).filter { text.contains($0) }
            #expect(stale.isEmpty, "\(document) still says \(stale.joined(separator: ", "))")
        }
    }

    @Test("The platform table in docs/PLATFORMS.md matches the build settings")
    func platforms() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
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

    /// The changelog says it follows Keep a Changelog, which means a heading in brackets is a link:
    /// without its definition the reader sees the brackets, and released versions carry a date.
    @Test("Every bracketed changelog heading has a link definition, and released versions have a date")
    func changelogFormat() throws {
        let text = try Repo.text("CHANGELOG.md")
        let headings = text.matches(of: /\n## \[([^\]]+)\]([^\n]*)/)
        #expect(!headings.isEmpty)
        for heading in headings {
            let name = String(heading.output.1)
            #expect(text.contains("\n[\(name)]: http"), "CHANGELOG.md: [\(name)] has no link definition")
            guard name != "Unreleased" else { continue }
            #expect(heading.output.2.contains(/[ ]-[ ]\d{4}-\d{2}-\d{2}/) || heading.output.2.contains("and earlier"),
                    "CHANGELOG.md: [\(name)] has no ISO date")
        }
    }

    /// The user-facing documents are one file with an English half and an Italian half. A question
    /// answered in one language only is the way that promise breaks, so the halves are compared.
    @Test("The bilingual documents answer the same things in both languages", arguments: ["SUPPORT.md", "PRIVACY.md"])
    func bilingualParity(document: String) throws {
        let text = try Repo.text(document)
        let halves = text.components(separatedBy: "\n---\n")
        try #require(halves.count == 2, "\(document): expected an English half and an Italian half, split by a rule")
        // Not the headings: each half opens with its own title, at a different level. What must match
        // is the substance — one bold-led entry per question or promise, one bullet per way to get
        // help, one table row per revision.
        let shape = { (half: String) in
            (leads: half.matches(of: /\n\*\*[^*]+\*\*/).count,
             bullets: half.matches(of: /\n-[ ]/).count,
             rows: half.components(separatedBy: "\n| ").count - 1)
        }
        let english = shape(halves[0]), italian = shape(halves[1])
        #expect(english.leads == italian.leads, "\(document): \(english.leads) English entries, \(italian.leads) Italian")
        #expect(english.bullets == italian.bullets, "\(document): \(english.bullets) English bullets, \(italian.bullets) Italian")
        #expect(english.rows == italian.rows, "\(document): \(english.rows) English table rows, \(italian.rows) Italian")
    }

    /// A document nobody links to is a document nobody reads, and nobody updates.
    @Test("Every Markdown file is reachable from an index")
    func indexed() throws {
        // GitHub reads these by their path; the guide has its own index, checked by UserGuideTests.
        let byPath: Set = [".github/PULL_REQUEST_TEMPLATE.md", "README.md"]
        let files = Repo.files(in: ".", extensions: ["md"]).map(Repo.relativePath)
            .filter { !$0.contains("/.build/") && !$0.hasPrefix("docs/guide/") && !byPath.contains($0) }
        let indexes = try ["README.md", "docs/README.md", "docs/adr/README.md", "CONTRIBUTING.md", "SUPPORT.md"]
            .map(Repo.text).joined(separator: "\n")
        for file in files {
            // A README is linked by the folder it belongs to ("adr/README.md"), anything else by name.
            let parts = file.split(separator: "/")
            let name = String(parts.last ?? "")
            let linked = name == "README.md" ? parts.suffix(2).joined(separator: "/") : name
            #expect(indexes.contains(linked), "nothing links to \(file): add it to docs/README.md")
        }
    }
}
