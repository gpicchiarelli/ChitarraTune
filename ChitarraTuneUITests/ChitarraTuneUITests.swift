import XCTest

final class ChitarraTuneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchAndFindTitleAndMode() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_AUDIO"] = "1"
        app.launch()

        // Title via accessibility identifier
        let titleById = app.staticTexts["appTitleLabel"]
        let titleAny = app.otherElements["appTitleLabel"]
        XCTAssertTrue(titleById.waitForExistence(timeout: 12) || titleAny.exists, "App title not found")

        // Mode segmented control by identifier
        let modePicker = app/* segmentedControls or generic */.segmentedControls["modePicker"]
        if !modePicker.exists {
            // Fallback search among any elements by identifier
            let anyMode = app.otherElements["modePicker"]
            XCTAssertTrue(anyMode.exists, "Mode picker not found")
        }
    }
}
