import XCTest

final class ChitarraTuneUITests: XCTestCase {
    override class func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLaunchAndFindTitleAndMode() {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_DISABLE_AUDIO"] = "1"
        app.launch()

        // Title (localized "ChitarraTune") should be visible
        let titlePredicate = NSPredicate(format: "label CONTAINS[c] 'ChitarraTune'")
        let title = app.staticTexts.element(matching: titlePredicate)
        XCTAssertTrue(title.waitForExistence(timeout: 10), "App title not found")

        // Mode label (IT/EN)
        let modeIT = app.staticTexts["Modalità"]
        let modeEN = app.staticTexts["Mode"]
        XCTAssertTrue(modeIT.exists || modeEN.exists, "Mode label not found")
    }
}

