import Foundation
import Testing

/// ADR 0014: the Developer ID download is a disk image built Apple's way, not a zip.
@Suite("Disk image distribution (ADR 0014)")
struct DiskImagePolicyTests {
    @Test("Apple's packaging requirements live in the script, not only in the ADR")
    func recipe() throws {
        let script = try Repo.text("Scripts/make-dmg.sh")
        // Comment lines may explain the ban in prose ("never cp", "no AppleScript"); only the code
        // that actually runs must avoid these.
        let code = script.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        #expect(script.contains("ditto \"$APP\""), "the staging area is populated with ditto")
        #expect(!code.contains("cp -R") && !code.contains("cp -r"), "cp resolves the Applications symlink")
        #expect(!code.contains("osascript") && !code.contains("AppleScript"), "the layout is headless, no Finder automation")
        #expect(script.contains("-format UDZO"), "Apple requires a UDIF read-only, zip-compressed image")
        #expect(script.contains("hdiutil create -srcfolder"))
        #expect(script.contains("--timestamp"), "a Developer ID signature needs a secure timestamp")
        #expect(script.contains("xcrun stapler staple"), "without a stapled ticket Gatekeeper blocks offline users")
        #expect(script.contains("-nobrowse") && script.contains("-readonly") && script.contains("-mountpoint"))
        #expect(script.contains("hdiutil detach") && script.contains("trap cleanup EXIT"), "a mount is always released")
        #expect(script.contains("SCRATCH"), "built outside the repository: iCloud extended attributes break codesign")
        #expect(script.contains("plutil -extract Format raw"), "hdiutil's prose is localized; read the plist, not the text")
    }

    @Test("The image signs under an identifier that is no bundle identifier in the product")
    func identifier() throws {
        let app = try #require(try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")["PRODUCT_BUNDLE_IDENTIFIER"])
        let controls = try #require(try Repo.xcconfig("Config/Base.xcconfig", "Config/Controls.xcconfig")["PRODUCT_BUNDLE_IDENTIFIER"])
        let identifier = "\(app).dmg"
        #expect(identifier != app && identifier != controls, "Apple requires an identifier of its own")
        #expect(identifier.hasPrefix(app + "."), "…built from the bundle identifier as a prefix")
        #expect(try Repo.text("Scripts/make-dmg.sh").contains("IDENTIFIER=\"\(identifier)\""))
    }

    @Test("An unknown argument is a usage error, like every other script here")
    func usage() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [Repo.url("Scripts/make-dmg.sh").path, "--nonsense"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 64)
    }

    @Test("The script is executable and the ADR is indexed")
    func present() {
        #expect(FileManager.default.isExecutableFile(atPath: Repo.url("Scripts/make-dmg.sh").path))
        #expect(Repo.exists("docs/adr/0014-disk-image-distribution.md"))
    }
}
