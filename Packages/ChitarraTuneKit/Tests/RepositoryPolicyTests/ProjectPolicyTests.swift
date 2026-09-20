import Foundation
import Testing

/// What must live in the app target — scenes, views, the localized string symbols, the App Intents
/// metadata — is tested by a unit-test bundle hosted by the app, because `swift test` cannot reach
/// it (ADR 0005). These tests keep that bundle wired up: a target nobody runs is worse than none.
@Suite("The app target is tested too")
struct ProjectPolicyTests {
    private static let project = "ChitarraTune.xcodeproj/project.pbxproj"
    private static let scheme = "ChitarraTune.xcodeproj/xcshareddata/xcschemes/ChitarraTune.xcscheme"

    @Test("The project has a unit-test target hosted by the app")
    func target() throws {
        let project = try Repo.text(Self.project)
        #expect(project.contains("name = ChitarraTuneTests;"))
        #expect(project.contains(#"productType = "com.apple.product-type.bundle.unit-test";"#),
                "ChitarraTuneTests must be a unit-test bundle, not another UI test runner")
        // Hosted by the app: the code under test reads the app's string catalog and preferences.
        let settings = try Repo.xcconfig("Config/Tests.xcconfig")
        #expect(settings["TEST_HOST"]?.contains("ChitarraTune.app") == true)
        #expect(settings["BUNDLE_LOADER"] == "$(TEST_HOST)")
        #expect(settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.chitarratune.app.tests")
        #expect(settings["SWIFT_DEFAULT_ACTOR_ISOLATION"] == "MainActor", "as in the app target")
    }

    /// CI runs `xcodebuild test -scheme ChitarraTune` with no `-only-testing`, so what the scheme
    /// lists is what runs: on iPhone, on iPad and on the Mac.
    @Test("The shared scheme runs both test bundles")
    func scheme() throws {
        let scheme = try Repo.text(Self.scheme)
        for bundle in ["ChitarraTuneTests", "ChitarraTuneUITests"] {
            #expect(scheme.contains("BuildableName = \"\(bundle).xctest\""), "the scheme does not run \(bundle)")
            let skipped = scheme.components(separatedBy: "BlueprintName = \"\(bundle)\"").count - 1
            #expect(skipped == 1, "\(bundle) appears \(skipped) times in the scheme")
        }
    }

    @Test("The app's own logic has tests")
    func tests() {
        let files = Repo.files(in: "ChitarraTuneTests", extensions: ["swift"])
        #expect(files.count >= 2)
        let sources = files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        #expect(sources.contains("@testable import ChitarraTune"))
        // The parts of the app that are logic, not layout, and would otherwise be tested by nothing.
        for subject in ["NoteParts", "spokenName", "signedText", "TuningOption", "LaunchOptions",
                        "MetricsReporter", "Diagnostics", "CaptureFailure"] {
            #expect(sources.contains(subject), "nothing tests \(subject) any more")
        }
    }
}
