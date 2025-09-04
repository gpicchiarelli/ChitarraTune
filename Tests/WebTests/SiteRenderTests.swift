import XCTest

final class SiteRenderTests: XCTestCase {
    private func read(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testIndexHasLocalizedHeroAndDownloadButton() throws {
        let html = try read("docs/index.html")
        XCTAssertTrue(html.contains("<h1 lang=\"it\">"))
        XCTAssertTrue(html.contains("<h1 lang=\"en\">"))
        XCTAssertTrue(html.contains("id=\"download-btn\""))
        XCTAssertTrue(html.contains("assets/js/main.js"))
    }

    func testBugPageLinksToGitHubIssuesTemplates() throws {
        let html = try read("docs/bug.html")
        XCTAssertTrue(html.contains("issues/new?template=bug_report_it.md"))
        XCTAssertTrue(html.contains("issues/new?template=bug_report_en.md"))
    }

    func testLicenseAnd404ExistAndContainTitles() throws {
        let lic = try read("docs/license.html")
        XCTAssertTrue(lic.lowercased().contains("licenza"))
        let notFound = try read("docs/404.html")
        XCTAssertTrue(notFound.contains("Pagina non trovata") || notFound.contains("Page not found"))
    }
}

