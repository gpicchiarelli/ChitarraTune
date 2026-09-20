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

    override func tearDown() async throws {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    // MARK: Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForTuner(file: StaticString = #filePath, line: UInt = #line) {
        #if os(macOS)
        // AppKit opens the first window when the app becomes active. A runner that launched it in
        // the background (CI, or a Mac in use) must bring it forward.
        if !element("listenButton").waitForExistence(timeout: 15) { app.activate() }
        #endif
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15), "Tuner did not appear", file: file, line: line)
    }

    /// Xcode's automatic accessibility audit: element descriptions, hit regions, traits, actions,
    /// clipping and Dynamic Type. Every issue is reported with the element it concerns, then the test
    /// fails once. The few accepted exceptions are in ``isAcceptedException(_:)``, each with its reason.
    ///
    /// Contrast is not sampled here. The audit reads rendered pixels and flags black text on white
    /// once Liquid Glass or an animated background is nearby; contrast is instead computed exactly,
    /// with the WCAG formula, for every colour of the asset catalog in every appearance, by
    /// `ColorContrastTests`.
    private func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) throws {
        // Let transitions finish (the background fades between states over 0.6 s), so the audit
        // measures the screen as the user sees it, not a frame in between.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1)
        var problems: [String] = []
        // A slow CI runner can make the audit itself time out (error -56); that is not a finding, so
        // it gets one more try.
        for attempt in 1...2 {
            var unattributed = false
            do {
                try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(.contrast)) { issue in
                    if self.isAcceptedException(issue) { return true }
                    guard let element = issue.element else {
                        unattributed = true
                        problems.append("\(issue.compactDescription) — no element")
                        return true
                    }
                    problems.append("\(issue.compactDescription) — "
                        + "\(element.elementType.rawValue) '\(element.identifier)' '\(element.label)' at \(element.frame)")
                    return true
                }
            } catch let error as NSError where error.code == -56 && attempt == 1 {
                problems.removeAll()
                continue
            }
            // Every accepted exception is keyed on the element the issue concerns, so an issue the
            // audit could not attach to one cannot be judged at all: the snapshot was incomplete,
            // which a loaded runner causes, and the same finding would be accepted with its element.
            // The audit is taken again rather than reported. A second incomplete snapshot is reported,
            // so a problem that is really there still fails the test.
            if unattributed, attempt == 1 {
                problems.removeAll()
                continue
            }
            break
        }
        if !problems.isEmpty {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Audit — \(screen)"
            shot.lifetime = .keepAlways
            add(shot)
            XCTFail("\(screen):\n  " + problems.joined(separator: "\n  "), file: file, line: line)
        }
    }

    /// Accepted audit findings. Keep this list short and justified.
    private func isAcceptedException(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        // Text behind a modal sheet is visible but deliberately out of reach of assistive tools
        // while the sheet is open; the audit reports it without an element.
        if issue.element == nil, issue.compactDescription.hasPrefix("Potentially inaccessible text") { return true }
        #if os(macOS)
        // The Touch Bar and the content groups of windows and sheets are AppKit's, not the app's.
        if let element = issue.element {
            if element.elementType == .touchBar { return true }
            // SwiftUI's menu-style Picker is a system pop-up button that opens its menu when pressed;
            // the audit does not see the press action AppKit gives it.
            if element.elementType == .popUpButton, issue.auditType == .action { return true }
            // Controls in the window toolbar are hosted by AppKit's toolbar item, which the audit
            // inspects instead of the pop-up button inside it (that keeps its label and action).
            if app.toolbars.firstMatch.exists, app.toolbars.firstMatch.frame.contains(element.frame),
               issue.auditType == .action || issue.auditType == .sufficientElementDescription
                || issue.auditType == .parentChild { return true }
            let window = app.windows.firstMatch
            if element.elementType == .group, element.label.isEmpty, window.exists, element.frame == window.frame { return true }
            let sheet = app.sheets.firstMatch
            if element.elementType == .group, element.label.isEmpty, sheet.exists, element.frame == sheet.frame { return true }
        }
        #endif
        #if os(iOS)
        guard issue.auditType == .dynamicType, let element = issue.element else { return false }
        // The ♭ and ♯ at the ends of the gauge are decorative (hidden from VoiceOver) and sized to
        // the gauge, which is a drawing.
        if ["♭", "♯"].contains(element.label) { return true }
        // The note name is already 88 pt at the default size and is capped at accessibility2 so
        // that it always fits on screen; the same information is spoken by VoiceOver and shown as
        // text beside the gauge.
        let readout = app.descendants(matching: .any).matching(identifier: "noteReadout").firstMatch
        if readout.exists, readout.frame.intersects(element.frame), element.frame.height > 60 { return true }
        // Bar buttons are capped by the system and offer the Large Content Viewer instead.
        if app.navigationBars.allElementsBoundByIndex.contains(where: { $0.frame.contains(element.frame) }) { return true }
        // Rows, headers and footers of the Settings form are system list cells, which scale their
        // own text (on iPad a form sheet keeps its width, so the audit reports them as partial).
        if app.collectionViews.allElementsBoundByIndex.contains(where: { $0.frame.contains(element.frame) }) { return true }
        #endif
        return false
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
        let hasNote = NSPredicate(format: "value MATCHES %@", "^[A-G]( sharp| flat)?, octave [0-9], .*")
        expectation(for: hasNote, evaluatedWith: readout)
        waitForExpectations(timeout: 15)
    }

    // MARK: Permission

    func testMicrophoneIsExplainedBeforeTheSystemPrompt() {
        app.launchArguments += ["-demoPermission", "notDetermined"]
        app.launch()
        waitForTuner()
        element("listenButton").tap()
        XCTAssertTrue(element("primerContinue").waitForExistence(timeout: 15), "explanation did not appear")

        element("primerContinue").tap()
        let stop = NSPredicate(format: "label == %@", "Stop")
        expectation(for: stop, evaluatedWith: element("listenButton"))
        waitForExpectations(timeout: 10)
    }

    func testNotNowLeavesTheTunerIdle() {
        app.launchArguments += ["-demoPermission", "notDetermined"]
        app.launch()
        waitForTuner()
        element("listenButton").tap()
        XCTAssertTrue(element("primerNotNow").waitForExistence(timeout: 15))
        element("primerNotNow").tap()
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15))
        XCTAssertEqual(element("listenButton").label, "Start Listening")
    }

    func testDeniedMicrophoneShowsTheWayOut() {
        app.launchArguments += ["-demoPermission", "denied"]
        app.launch()
        waitForTuner()
        element("listenButton").tap()
        XCTAssertTrue(element("failureView").waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    // MARK: Controls

    func testPinningAStringSelectsItAndAutoReleasesIt() {
        app.launch()
        waitForTuner()
        let third = element("stringChip.3")
        third.tap()
        #if os(iOS)
        // The selected trait surfaces as `isSelected` on iOS; on macOS AppKit does not expose it for
        // buttons to XCTest (VoiceOver still announces it), so there the taps are only exercised.
        XCTAssertTrue(third.isSelected, "pinned string should be selected")
        XCTAssertFalse(element("autoChip").isSelected)
        #endif

        element("autoChip").tap()
        #if os(iOS)
        XCTAssertTrue(element("autoChip").isSelected)
        XCTAssertFalse(third.isSelected)
        #endif
        XCTAssertTrue(element("listenButton").exists)
    }

    func testChangingTuningRelabelsTheStrings() {
        app.launch()
        waitForTuner()
        XCTAssertEqual(element("stringChip.1").label, "E2")

        element("tuningPicker").tap()
        #if os(macOS)
        // A pop-up button's items are menu items, whose text is their title.
        let dropD = app.menuItems.matching(NSPredicate(format: "title CONTAINS %@", "Drop D")).firstMatch
        #else
        let dropD = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Drop D")).firstMatch
        #endif
        XCTAssertTrue(dropD.waitForExistence(timeout: 15))
        dropD.tap()

        let relabelled = NSPredicate(format: "label == %@", "D2")
        expectation(for: relabelled, evaluatedWith: element("stringChip.1"))
        waitForExpectations(timeout: 10)
    }

    #if os(iOS)
    func testSettingsSheetOpensAndCloses() {
        app.launch()
        waitForTuner()
        element("settingsButton").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Reference Pitch (A4)"].firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15))
    }
    #endif

    // MARK: Accessibility audits, one per screen and state

    func testAccessibilityAuditTuner() throws {
        app.launch()
        waitForTuner()
        try audit("Tuner")
    }

    func testAccessibilityAuditWhileListening() throws {
        app.launchArguments += ["-autostart"]
        app.launch()
        waitForTuner()
        let hasNote = NSPredicate(format: "value MATCHES %@", "^[A-G]( sharp| flat)?, octave [0-9], .*")
        expectation(for: hasNote, evaluatedWith: element("noteReadout"))
        waitForExpectations(timeout: 15)
        try audit("Tuner while listening")
    }

    func testAccessibilityAuditMicrophoneExplanation() throws {
        app.launchArguments += ["-demoPermission", "notDetermined"]
        app.launch()
        waitForTuner()
        element("listenButton").tap()
        XCTAssertTrue(element("primerContinue").waitForExistence(timeout: 15))
        try audit("Microphone explanation")
    }

    func testAccessibilityAuditFailure() throws {
        app.launchArguments += ["-demoPermission", "denied"]
        app.launch()
        waitForTuner()
        element("listenButton").tap()
        XCTAssertTrue(element("failureView").waitForExistence(timeout: 15))
        try audit("Microphone denied")
    }

    #if os(iOS)
    func testAccessibilityAuditSettings() throws {
        app.launch()
        waitForTuner()
        element("settingsButton").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        try audit("Settings")
    }

    func testAccessibilityAuditLargestText() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        waitForTuner()
        try audit("Tuner at the largest text size")
    }

    func testAccessibilityAuditDarkWhileListening() throws {
        // The app's own Dark Mode switch: flipping the simulator's appearance between launches makes
        // the next launch flaky on CI.
        app.launchArguments += ["-autostart", "-demoAppearance", "dark"]
        app.launch()
        waitForTuner()
        let hasNote = NSPredicate(format: "value MATCHES %@", "^[A-G]( sharp| flat)?, octave [0-9], .*")
        expectation(for: hasNote, evaluatedWith: element("noteReadout"))
        waitForExpectations(timeout: 15)
        element("stringChip.3").tap()
        try audit("Tuner in Dark Mode, string pinned")
    }

    func testAccessibilityAuditLandscape() throws {
        // Rotate after the app is up, not before. Rotating an empty Springboard and launching into the
        // new orientation makes the launch race the rotation: the accessibility server was still
        // applying it when the test asked for the list of running applications, and answered with
        // kAXErrorIPCTimeout after 114 s on CI. Rotating a running app exercises the same layout.
        app.launch()
        waitForTuner()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15), "Tuner did not survive the rotation")
        try audit("Tuner in landscape")
    }
    #endif

    // MARK: Performance

    func testLaunchPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"] == "1",
                          "Enable with RUN_PERFORMANCE_TESTS=1")
        measure(metrics: [XCTApplicationLaunchMetric()]) { app.launch() }
    }
}
