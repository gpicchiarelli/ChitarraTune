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

        // Mode segmented control: be resilient across macOS/SwiftUI mappings
        let modeById = app.segmentedControls["modePicker"]
        let modeAny = app.otherElements["modePicker"]
        let existsById = modeById.waitForExistence(timeout: 6)
        let existsAny = modeAny.exists
        // Fallback: look for segments labeled Auto/Manual (IT/EN)
        let autoBtn = app.buttons["Auto"]
        let manualBtnIT = app.buttons["Manuale"]
        let manualBtnEN = app.buttons["Manual"]
        let existsSegments = autoBtn.exists && (manualBtnIT.exists || manualBtnEN.exists)
        XCTAssertTrue(existsById || existsAny || existsSegments || app.segmentedControls.element.exists, "Mode picker not found")
    }
}
