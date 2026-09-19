# Code signing and entitlements

## Local development

`Config/Base.xcconfig` sets automatic signing with the maintainer's team. To build with your own team, create `Config/Local.xcconfig` (it is ignored by git; never commit it):

```
DEVELOPMENT_TEAM = YOURTEAMID
```

macOS 26 may refuse to launch an unsigned executable started from Xcode, so use a personal team if you have no paid account. Building from the command line without signing works, but the result is only good for compile checks:

```bash
xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## What the app may do

| Setting | Where | Effect |
| --- | --- | --- |
| App Sandbox (macOS) | `ENABLE_APP_SANDBOX` in `Config/App.xcconfig` | Container-only file access |
| Audio input (macOS) | `ENABLE_RESOURCE_ACCESS_AUDIO_INPUT` in `Config/App.xcconfig` | The microphone, and nothing else |
| No network | `ENABLE_INCOMING_NETWORK_CONNECTIONS = NO`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO` | No socket access at all |
| Hardened Runtime | `ENABLE_HARDENED_RUNTIME` in `Config/Base.xcconfig` | Required for notarization |
| Enhanced Security | `ENABLE_ENHANCED_SECURITY`, plus the `com.apple.security.hardened-process.*` keys in `Config/ChitarraTune.entitlements` | Hardened heap, read-only dyld, platform restrictions |
| Microphone text | `INFOPLIST_KEY_NSMicrophoneUsageDescription`, localized in `InfoPlist.xcstrings` | The permission prompt |

Note that the sandbox and audio-input entitlements come from **build settings**, so Xcode generates the final entitlement set at build time. Signing must therefore go through `xcodebuild` (as the release workflow does), not through a separate `codesign --entitlements Config/ChitarraTune.entitlements` step, which would leave those two out.

Pointer Authentication is on in every build that ships. An `arm64e` target can only import `arm64e` modules, and xcconfig settings never reach local SwiftPM targets, so `Config/App.xcconfig` leaves it off (Xcode's own builds keep working) and the release workflow passes `ENABLE_POINTER_AUTHENTICATION=YES` on the `xcodebuild` command line, where it applies to every target, packages included. The result, `arm64e` next to `arm64` (and `x86_64` on the Mac), is checked with `lipo` in the release and on every push in CI.

## Release readiness

Everything notarization and App Review check about the bundle is checked on every push, without a certificate ([ADR 0013](adr/0013-release-readiness.md)): the `release` job of CI builds the Mac app exactly as a release and runs `Scripts/release-check.sh` on it (identifiers, versions, minimum system, category, export compliance, purpose strings in both languages, privacy manifest, icon, `arm64e`/`arm64`/`x86_64`, system-only linkage, dSYM, a strict signature, exactly the allowed entitlements, no `get-task-allow`, the Hardened Runtime setting). The release workflow runs the same script on its signed build before notarizing. Release builds never carry development entitlements (`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`).

The same job also builds an ad-hoc disk image from that build with `Scripts/make-dmg.sh` and checks its format, its contents, the `Applications` symlink and its signing identifier — see [Disk image](#disk-image) below and [ADR 0014](adr/0014-disk-image-distribution.md).

Locally:

```bash
Scripts/release-check.sh
```

With a *Developer ID Application* certificate in your keychain, and a `notarytool` profile created once with `xcrun notarytool store-credentials chitarratune --apple-id you@example.com --team-id TEAMID`, the same script signs, notarizes, staples and asks Gatekeeper:

```bash
Scripts/release-check.sh --identity "Developer ID Application: Your Name (TEAMID)" --notarize chitarratune
```

**Prerequisite: a paid Apple Developer Program membership.** A personal (free) team cannot create Developer ID certificates and cannot sign this app at all, because it cannot grant the Enhanced Security capability ([ADR 0003](adr/0003-least-privilege-and-platform-security.md)).

## Release signing (CI)

The [release workflow](../.github/workflows/release.yml) runs on a `vX.Y.Z` tag or by hand, only from a commit that is on `main`, and only when `MARKETING_VERSION` and `CHANGELOG.md` already carry that version (`Scripts/bump-version.sh` prepares both). It publishes on two channels:

**Developer ID (Mac, outside the store).** It builds with Manual signing and your *Developer ID Application* certificate, verifies the signature, the Hardened Runtime flag and the sandbox of the app and of the Controls extension, and the audio-input entitlement of the app; notarizes the app with `notarytool` and staples its ticket; wraps it in a disk image (`Scripts/make-dmg.sh`), signs the image under its own identifier, notarizes it in a submission of its own and staples it too; computes a SHA-256 checksum and a build-provenance attestation of the image; and creates the GitHub Release with the changelog section as notes.

**App Store (iPhone, iPad, Mac).** For each platform it archives with **cloud-managed signing** (`-allowProvisioningUpdates` with the App Store Connect API key: Xcode obtains the Apple Distribution certificate and the provisioning profiles for the app and the extension, so no distribution certificate is stored anywhere), then exports with `Config/ExportOptions-AppStore.plist`, which uploads the build to App Store Connect. The build appears in TestFlight once processed; submission for review is manual (see [AppStore/README.md](../AppStore/README.md)). Pre-release versions such as `2.1.0-beta.1` go to the Developer ID channel only.

A manual run can choose the channel (`both`, `developer-id`, `app-store`).

| Secret | Used by | Content |
| --- | --- | --- |
| `APPLE_TEAM_ID` | both | Your Apple Developer Team ID |
| `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID` | both | App Store Connect API key (role **App Manager**) |
| `ASC_API_KEY_P8` | both | Base64 of the API key (`base64 -i AuthKey_XXXX.p8`) |
| `MACOS_CERT_P12` | Developer ID | Base64 of the *Developer ID Application* certificate (`.p12`) |
| `MACOS_CERT_PASSWORD` | Developer ID | Password of the `.p12` |

Without the certificate and team the Developer ID job refuses to publish, unless a manual run opts in to an **unsigned** build with `allow_unsigned` (the release is then labeled as such). Without the API key the Developer ID build is signed but not notarized, and the App Store job fails.

Secrets are exposed only to the steps that need them, and the temporary keychain and key files are removed at the end of every run.

## Disk image

The Developer ID artifact is a disk image, not a zip ([ADR 0014](adr/0014-disk-image-distribution.md)): `Scripts/make-dmg.sh` stages the already-notarized-and-stapled app with `ditto`, adds a symlink to `/Applications` and a volume icon, and builds a UDIF read-only, zip-compressed (`UDZO`) image with `hdiutil`. The image is then signed under its own code-signing identifier, `com.chitarratune.app.dmg` — prefixed by the app's bundle identifier and equal to no bundle identifier in the product, as Apple's packaging guide requires — notarized in a submission of its own, and stapled. Two notarizations, one artifact: the app keeps working once dragged out and offline, and so does the image before it is ever opened.

Locally:

```bash
Scripts/make-dmg.sh                                             # ad hoc, from the app Scripts/release-check.sh just built
Scripts/make-dmg.sh --app path/to/ChitarraTune.app \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notarize chitarratune --output ChitarraTune-2.0.1.dmg        # signed, notarized and stapled
Scripts/make-dmg.sh --verify ChitarraTune-2.0.1.dmg --signed --stapled   # check one someone else built
```

## The Controls extension

`ChitarraTuneControls.appex` (`com.chitarratune.app.controls`) is signed like the app, with its own entitlements (`Config/ChitarraTuneControls.entitlements`): the same Enhanced Security keys, the macOS App Sandbox, no network and no resources at all, not even the microphone. The intent it triggers runs in the app.

## Gatekeeper

Downloading the disk image quarantines it; the stapled ticket is what lets it open with no warning and no network, both for the image and for the app once it is dragged out. An unsigned or non-notarized image shows "Apple cannot check it for malicious software" the moment it is opened. Verify the published SHA-256, then use **Right-click → Open** once.
