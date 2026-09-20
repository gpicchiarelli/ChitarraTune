import Foundation
import Testing

/// The privacy and security promises of README.md, PRIVACY.md and SECURITY.md, as executable checks.
@Suite("Security and privacy policy")
struct SecurityPolicyTests {
    @Test("The repository is found (guards every other test in this target)")
    func repositoryRoot() {
        #expect(Repo.exists("Packages/ChitarraTuneKit/Package.swift"), "root resolved to \(Repo.root.path)")
        #expect(Repo.exists("LICENSE"))
    }

    @Test("Sandbox, hardened runtime and strict concurrency are on")
    func hardening() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        #expect(s["ENABLE_APP_SANDBOX[sdk=macosx*]"] == "YES")
        #expect(s["ENABLE_HARDENED_RUNTIME"] == "YES")
        #expect(s["ENABLE_ENHANCED_SECURITY"] == "YES")
        // Shipping builds get pointer authentication from the command line (an xcconfig cannot reach the
        // SwiftPM targets): both release channels and CI must pass it, and CI must check the result.
        let release = try Repo.text(".github/workflows/release.yml")
        #expect(release.components(separatedBy: "ENABLE_POINTER_AUTHENTICATION=YES").count - 1 >= 2, "both release channels must build arm64e")
        #expect(release.contains("grep -qw arm64e"), "the release must verify the binaries are arm64e")
        let ci = try Repo.text(".github/workflows/ci.yml")
        #expect(ci.contains("ENABLE_POINTER_AUTHENTICATION=YES") && ci.contains("grep -qw arm64e"),
                "CI must build the iOS slice with pointer authentication and check the result")
        #expect(ci.contains("run: Scripts/release-check.sh"),
                "the macOS slice is checked by release-check.sh on every push (ADR 0013)")
        let checker = try Repo.text("Scripts/release-check.sh")
        #expect(checker.contains("ENABLE_POINTER_AUTHENTICATION=YES") && checker.contains("arm64e"),
                "release-check.sh must build with pointer authentication and verify the slices")
        #expect(s["ENABLE_USER_SCRIPT_SANDBOXING"] == "YES")
        #expect(s["SWIFT_VERSION"] == "6.0")
        #expect(s["SWIFT_STRICT_CONCURRENCY"] == "complete")
    }

    @Test("There is no network access, and the microphone is the only resource entitlement")
    func leastPrivilege() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        #expect(s["ENABLE_INCOMING_NETWORK_CONNECTIONS"] == "NO")
        #expect(s["ENABLE_OUTGOING_NETWORK_CONNECTIONS"] == "NO")
        let resources = s.keys.filter { $0.hasPrefix("ENABLE_RESOURCE_ACCESS_") }
        #expect(resources == ["ENABLE_RESOURCE_ACCESS_AUDIO_INPUT[sdk=macosx*]"], "unexpected resources: \(resources)")

        let forbidden = ["com.apple.security.network.", "com.apple.security.files.", "com.apple.security.personal-information.",
                         "com.apple.security.device.", "com.apple.security.cs.disable-", "com.apple.security.cs.allow-",
                         "com.apple.security.application-groups", "com.apple.security.temporary-exception"]
        for file in ["Config/ChitarraTune.entitlements", "Config/ChitarraTuneControls.entitlements"] {
            let entitlements = try Repo.plist(file)
            for key in entitlements.keys {
                #expect(!forbidden.contains { key.hasPrefix($0) }, "\(file): entitlement \(key) widens the sandbox")
            }
            #expect(entitlements["com.apple.security.hardened-process"] as? Bool == true, "\(file) lacks Enhanced Security")
        }
    }

    @Test("Release builds never carry development entitlements (ADR 0013)")
    func noDevelopmentEntitlementsInRelease() throws {
        let release = try Repo.xcconfig("Config/Base.xcconfig", "Config/Release.xcconfig")
        #expect(release["CODE_SIGN_INJECT_BASE_ENTITLEMENTS"] == "NO", "get-task-allow would be injected; notarization rejects it")
        for file in ["Config/ChitarraTune.entitlements", "Config/ChitarraTuneControls.entitlements"] {
            #expect(try Repo.plist(file)["com.apple.security.get-task-allow"] == nil, "\(file) grants get-task-allow")
        }
    }

    @Test("The Controls extension is sandboxed, offline and needs no resource at all")
    func controlsExtension() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/Controls.xcconfig")
        #expect(s["ENABLE_APP_SANDBOX[sdk=macosx*]"] == "YES")
        #expect(s["ENABLE_INCOMING_NETWORK_CONNECTIONS"] == "NO" && s["ENABLE_OUTGOING_NETWORK_CONNECTIONS"] == "NO")
        #expect(!s.keys.contains { $0.hasPrefix("ENABLE_RESOURCE_ACCESS_") }, "the extension must not reach the microphone")
        #expect(s["APPLICATION_EXTENSION_API_ONLY"] == "YES")
        #expect(s["PRODUCT_BUNDLE_IDENTIFIER"] == "com.chitarratune.app.controls", "extension ids must be prefixed by the app's")
        let info = try Repo.plist("Config/Controls-Info.plist")
        #expect((info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension")
    }

    @Test("No background modes, and the store questions are answered")
    func metadata() throws {
        let s = try Repo.xcconfig("Config/Base.xcconfig", "Config/App.xcconfig")
        #expect(!s.keys.contains { $0.contains("UIBackgroundModes") })
        #expect(try Repo.plist("Config/Info.plist")["UIBackgroundModes"] == nil)
        #expect(s["INFOPLIST_KEY_ITSAppUsesNonExemptEncryption"] == "NO")
        let usage = try #require(s["INFOPLIST_KEY_NSMicrophoneUsageDescription"])
        #expect(usage.contains("never recorded"), "the permission text must state that audio is not recorded")
        #expect(s["MACOSX_DEPLOYMENT_TARGET"] == s["IPHONEOS_DEPLOYMENT_TARGET"], "one minimum for every platform")
    }

    @Test("The privacy manifest declares no tracking, no collected data, and only our own UserDefaults")
    func privacyManifest() throws {
        let manifest = try Repo.plist("App/Resources/PrivacyInfo.xcprivacy")
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        // Required-reason APIs the app may use, each with the only reason it may give. Anything new
        // (or any other reason) must be added here on purpose, in the same change.
        let allowed: [String: [String]] = [
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],   // the app's own settings
            "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"], // measuring elapsed time inside the app
        ]
        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        for entry in accessed {
            let category = try #require(entry["NSPrivacyAccessedAPIType"] as? String)
            #expect(allowed[category] != nil, "\(category) is not on the allowed list")
            #expect(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] == allowed[category], "unexpected reason for \(category)")
        }
        #expect(accessed.contains { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
    }

    @Test("Source code has no networking, tracking, cryptography or audio-file APIs")
    func forbiddenAPIs() throws {
        let tokens = ["URLSession", "URLRequest", "NWConnection", "NWPathMonitor", "import Network", "CFNetwork",
                      "WKWebView", "import WebKit", "import CryptoKit", "CommonCrypto", "AdSupport", "AppTrackingTransparency",
                      "AVAudioRecorder", "AVAudioFile", "AVAssetWriter", "AVCaptureAudioFileOutput", "SFSpeechRecognizer"]
        let sources = ["App", "Shared", "Controls", "Packages/ChitarraTuneKit/Sources"].flatMap { Repo.files(in: $0, extensions: ["swift"]) }
        #expect(sources.count > 20, "the scan found suspiciously few files")
        for file in sources {
            let code = try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for token in tokens {
                #expect(!code.contains(token), "\(Repo.relativePath(file)) uses \(token)")
            }
        }
    }

    @Test("The package has no third-party dependencies")
    func noDependencies() throws {
        let manifest = try Repo.text("Packages/ChitarraTuneKit/Package.swift")
        #expect(!manifest.contains(".package("))
        #expect(!Repo.exists("Packages/ChitarraTuneKit/Package.resolved"))
        #expect(!Repo.exists("Package.resolved"))
    }

    @Test("No secrets or signing material are committed")
    func noSecrets() throws {
        let patterns = ["-----BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----", "ghp_[A-Za-z0-9]{36}", "github_pat_[A-Za-z0-9_]{60,}",
                        "AKIA[0-9A-Z]{16}", "xox[baprs]-[A-Za-z0-9-]{10,}", "AIza[0-9A-Za-z_-]{35}"]
        let regexes = try patterns.map { try NSRegularExpression(pattern: $0) }
        let skip: Set<String> = ["png", "jpg", "jpeg", "icns", "ico", "gif", "zip", "dmg", "bundle", "svg"]
        let ignored = ["/.git/", "/.build/", "/build/", "/DerivedData/", "/.swiftpm/"]
        let forbiddenFiles: Set<String> = ["p12", "p8", "cer", "mobileprovision", "provisionprofile", "keychain", "pem"]
        var scanned = 0
        let walker = FileManager.default.enumerator(at: Repo.root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
        while let url = walker?.nextObject() as? URL {
            guard !ignored.contains(where: { url.path.contains($0) }),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            #expect(!forbiddenFiles.contains(url.pathExtension), "signing material committed: \(Repo.relativePath(url))")
            guard !skip.contains(url.pathExtension),
                  (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 < 2_000_000 }) ?? false,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            let range = NSRange(text.startIndex..., in: text)
            for regex in regexes {
                #expect(regex.firstMatch(in: text, range: range) == nil, "possible secret in \(Repo.relativePath(url))")
            }
        }
        #expect(scanned > 50)
    }

    @Test("Coverage is held at 100 % and the hardware boundary cannot hide code")
    func coverageGate() throws {
        let thresholds = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: Repo.url("Scripts/coverage-thresholds.json"))) as? [String: Int])
        #expect(thresholds == ["TunerAudio": 100, "TunerCore": 100, "TunerFeature": 100])
        let gate = try Repo.text("Scripts/coverage-gate.sh")
        #expect(gate.contains("IGNORE='/Tests/|/\\.build/|DerivedSources|/Sources/TunerAudio/Hardware/'"),
                "the coverage exclusions changed: they must stay limited to tests, build output and the hardware boundary")
        let hardware = try FileManager.default.contentsOfDirectory(atPath: Repo.url("Packages/ChitarraTuneKit/Sources/TunerAudio/Hardware").path)
        let allowed: Set = ["README.md", "EngineAudioCapture+System.swift", "MicrophonePrompt.swift", "CoreAudioDevices.swift", "SystemAudioInputs.swift"]
        #expect(Set(hardware) == allowed,
                "only the listed adapters may live in the uncovered hardware boundary")
    }

    @Test("The licence belongs to the contributors")
    func licence() throws {
        let licence = try Repo.text("LICENSE")
        #expect(licence.contains("BSD 3-Clause License"))
        #expect(licence.contains("ChitarraTune contributors"))
        #expect(Repo.exists("CONTRIBUTORS.md") && Repo.exists("PRIVACY.md") && Repo.exists("SECURITY.md"))
    }
}
