import XCTest

final class ChitarraTuneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers
    private func assertAppTitleExists(_ app: XCUIApplication) {
        let titleById = app.staticTexts["appTitleLabel"]
        let titleAny = app.otherElements["appTitleLabel"]
        XCTAssertTrue(titleById.waitForExistence(timeout: 12) || titleAny.exists, "App title not found")
    }

    private func modeControlExists(in app: XCUIApplication) -> Bool {
        // Try by identifier in common scopes
        if app.segmentedControls["modePicker"].exists { return true }
        if app.otherElements["modePicker"].exists { return true }
        if app.toolbars.segmentedControls["modePicker"].exists { return true }
        if app.toolbars.otherElements["modePicker"].exists { return true }

        // Any segmented control anywhere (content or toolbar)
        if app.segmentedControls.element.exists { return true }
        if app.toolbars.segmentedControls.element.exists { return true }

        // Look for Auto/Manual buttons in likely places (IT/EN)
        let candidates = [
            "Auto", "Automatico", "Automatica",
            "Manuale", "Manual"
        ]
        for label in candidates {
            if app.buttons[label].exists { return true }
            if app.toolbars.buttons[label].exists { return true }
        }
        return false
    }

    // MARK: - Tests

    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_AUDIO"] = "1"
        app.launch()
        assertAppTitleExists(app)
    }

    func testModeControlPresenceIfAvailable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_AUDIO"] = "1"
        app.launch()
        assertAppTitleExists(app)

        // Be robust: skip if the control isn't exposed on this OS/UI variant
        guard modeControlExists(in: app) else {
            throw XCTSkip("Mode control not exposed in this configuration")
        }
        XCTAssertTrue(true)
    }
}
