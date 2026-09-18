import XCTest

/// End-to-end tests. The app runs in demo mode (`-demo`): a synthetic guitar replaces the microphone,
/// so there is no permission prompt and the tests are deterministic on CI runners without audio hardware.
@MainActor
final class ChitarraTuneUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-demo", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    // MARK: Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForTuner(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15), "Tuner did not appear", file: file, line: line)
    }

    // MARK: Layout

    func testLaunchShowsTheWholeTuner() {
        app.launch()
        waitForTuner()
        XCTAssertTrue(element("tuningGauge").exists)
        XCTAssertTrue(element("noteReadout").exists)
        XCTAssertTrue(element("tuningPicker").exists)
        XCTAssertTrue(element("autoChip").exists)
        for number in 1...6 {
            XCTAssertTrue(element("stringChip.\(number)").exists, "string chip \(number) missing")
        }
    }

    // MARK: Listening

    func testStartStopToggles() {
        app.launch()
        waitForTuner()
        let button = element("listenButton")
        XCTAssertEqual(button.label, "Start Listening")

        button.tap()
        let stop = NSPredicate(format: "label == %@", "Stop")
        expectation(for: stop, evaluatedWith: button)
        waitForExpectations(timeout: 10)

        button.tap()
        let start = NSPredicate(format: "label == %@", "Start Listening")
        expectation(for: start, evaluatedWith: button)
        waitForExpectations(timeout: 10)
    }

    func testDetectsANoteWhileListening() {
        app.launchArguments += ["-autostart"]
        app.launch()
        waitForTuner()
        let readout = element("noteReadout")
        let hasNote = NSPredicate(format: "value MATCHES %@", "^[A-G][♯♭]?[0-9], .*")
        expectation(for: hasNote, evaluatedWith: readout)
        waitForExpectations(timeout: 15)
    }

    // MARK: Controls

    func testPinningAStringSelectsItAndAutoReleasesIt() {
        app.launch()
        waitForTuner()
        let third = element("stringChip.3")
        third.tap()
        XCTAssertTrue(third.isSelected, "pinned string should be selected")
        XCTAssertFalse(element("autoChip").isSelected)

        element("autoChip").tap()
        XCTAssertTrue(element("autoChip").isSelected)
        XCTAssertFalse(third.isSelected)
    }

    func testChangingTuningRelabelsTheStrings() {
        app.launch()
        waitForTuner()
        XCTAssertEqual(element("stringChip.1").label, "E2")

        element("tuningPicker").tap()
        let dropD = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Drop D")).firstMatch
        XCTAssertTrue(dropD.waitForExistence(timeout: 5))
        dropD.tap()

        let relabelled = NSPredicate(format: "label == %@", "D2")
        expectation(for: relabelled, evaluatedWith: element("stringChip.1"))
        waitForExpectations(timeout: 5)
    }

    #if os(iOS)
    func testSettingsSheetOpensAndCloses() {
        app.launch()
        waitForTuner()
        element("settingsButton").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reference Pitch (A4)"].firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 5))
    }
    #endif

    // MARK: Quality

    /// Xcode's automatic accessibility audit: labels, hit regions, Dynamic Type clipping, contrast.
    func testAccessibilityAudit() throws {
        app.launch()
        waitForTuner()
        try app.performAccessibilityAudit()
    }

    func testLaunchPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"] == "1",
                          "Enable with RUN_PERFORMANCE_TESTS=1")
        measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
    }
}
