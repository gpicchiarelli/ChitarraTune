import XCTest

/// App Store screenshots, in demo mode (synthetic guitar). Skipped unless `Scripts/screenshots.sh`
/// runs them (it sets `SCREENSHOTS=1` and the language), so they never slow down the normal suite.
@MainActor
final class AppStoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var language = "en"

    override func setUp() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SCREENSHOTS"] == "1", "Run through Scripts/screenshots.sh")
        continueAfterFailure = false
        language = environment["SCREENSHOT_LANGUAGE"] ?? "en"
        let locale = language == "it" ? "it_IT" : "en_US"
        app = XCUIApplication()
        app.launchArguments += ["-demo", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        #if os(macOS)
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
    }

    override func tearDown() async throws {
        #if os(iOS)
        XCUIDevice.shared.appearance = .light
        #endif
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func snapshot(_ name: String) {
        #if os(macOS)
        let image = app.windows.firstMatch.screenshot()
        #else
        let image = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForReadout(matching pattern: String, timeout: TimeInterval = 20) {
        let predicate = NSPredicate(format: "value MATCHES %@", pattern)
        expectation(for: predicate, evaluatedWith: element("noteReadout"))
        waitForExpectations(timeout: timeout)
    }

    private var inTunePattern: String { language == "it" ? ".*è intonata.*" : ".*is in tune.*" }

    /// 1. A string in tune. 2. The next string, still flat, with its advice.
    func test1Tuning() {
        app.launchArguments += ["-autostart"]
        app.launch()
        waitForReadout(matching: inTunePattern)
        snapshot("01-in-tune")

        // The demo plucks the next string about 28 cents flat and lets it drift up.
        let current = element("noteReadout").value as? String ?? ""
        let note = String(current.prefix { $0 != "," })
        let next = NSPredicate(format: "NOT (value BEGINSWITH %@) AND NOT (value MATCHES %@)", note + ",", inTunePattern)
        expectation(for: next, evaluatedWith: element("noteReadout"))
        waitForExpectations(timeout: 10)
        Thread.sleep(forTimeInterval: 0.4)
        snapshot("02-flat")
    }

    /// 3. Every tuning.
    func test2Tunings() {
        app.launch()
        XCTAssertTrue(element("tuningPicker").waitForExistence(timeout: 15))
        element("tuningPicker").tap()
        Thread.sleep(forTimeInterval: 0.8)
        snapshot("03-tunings")
    }

    /// 4. The bar gauge in Dark Mode (iPhone, iPad) with a pinned string.
    func test3BarGauge() {
        #if os(iOS)
        XCUIDevice.shared.appearance = .dark
        #endif
        app.launchArguments += ["-autostart", "-settings.gauge", "bar"]
        app.launch()
        XCTAssertTrue(element("stringChip.5").waitForExistence(timeout: 15))
        element("stringChip.5").tap()
        waitForReadout(matching: inTunePattern, timeout: 30)
        snapshot("04-bar-dark")
    }

    /// 5. Settings.
    func test4Settings() {
        app.launch()
        XCTAssertTrue(element("listenButton").waitForExistence(timeout: 15))
        #if os(macOS)
        app.typeKey(",", modifierFlags: .command)
        #else
        element("settingsButton").tap()
        #endif
        Thread.sleep(forTimeInterval: 1)
        #if os(macOS)
        let window = app.windows.element(boundBy: 0)
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "05-settings"
        attachment.lifetime = .keepAlways
        add(attachment)
        #else
        snapshot("05-settings")
        #endif
    }
}
