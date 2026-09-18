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

## What the app is allowed to do

| Setting | Where | Effect |
| --- | --- | --- |
| App Sandbox (macOS) | `ENABLE_APP_SANDBOX` in `Config/App.xcconfig` | Container-only file access |
| Audio input (macOS) | `ENABLE_RESOURCE_ACCESS_AUDIO_INPUT` in `Config/App.xcconfig` | The microphone, and nothing else |
| No network | `ENABLE_INCOMING_NETWORK_CONNECTIONS = NO`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO` | No socket access at all |
| Hardened Runtime | `ENABLE_HARDENED_RUNTIME` in `Config/Base.xcconfig` | Required for notarization |
| Enhanced Security | `ENABLE_ENHANCED_SECURITY`, plus the `com.apple.security.hardened-process.*` keys in `Config/ChitarraTune.entitlements` | Hardened heap, read-only dyld, platform restrictions |
| Microphone text | `INFOPLIST_KEY_NSMicrophoneUsageDescription`, localized in `InfoPlist.xcstrings` | The permission prompt |

Note that the sandbox and audio-input entitlements come from **build settings**, so Xcode generates the final entitlement set at build time. Signing must therefore go through `xcodebuild` (as the release workflow does), not through a separate `codesign --entitlements Config/ChitarraTune.entitlements` step, which would leave those two out.

Pointer Authentication is currently switched off (`ENABLE_POINTER_AUTHENTICATION = NO` in `Config/App.xcconfig`).

## Release signing (CI)

The [release workflow](.github/workflows/release.yml) runs on a `vX.Y.Z` tag or by hand, only from a commit that is on `main`, and only when `MARKETING_VERSION` and `CHANGELOG.md` already carry that version (`Scripts/bump-version.sh` prepares both). It publishes on two channels:

**Developer ID (Mac, outside the store).** It builds with Manual signing and your *Developer ID Application* certificate, verifies the signature, the Hardened Runtime flag and the sandbox of the app and of the Controls extension, and the audio-input entitlement of the app; notarizes with `notarytool` and staples the ticket; zips the app with a SHA-256 checksum and a build-provenance attestation; and creates the GitHub Release with the changelog section as notes.

**App Store (iPhone, iPad, Mac).** For each platform it archives with **cloud-managed signing** (`-allowProvisioningUpdates` with the App Store Connect API key: Xcode obtains the Apple Distribution certificate and the provisioning profiles for the app and the extension, so no distribution certificate is stored anywhere), then exports with `Config/ExportOptions-AppStore.plist`, which uploads the build to App Store Connect. The build appears in TestFlight once processed; submission for review is manual (see [AppStore/README.md](AppStore/README.md)). Pre-release versions such as `2.1.0-beta.1` go to the Developer ID channel only.

A manual run can choose the channel (`both`, `developer-id`, `app-store`).

| Secret | Used by | Content |
| --- | --- | --- |
| `APPLE_TEAM_ID` | both | Your Apple Developer Team ID |
| `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID` | both | App Store Connect API key (role **App Manager**) |
| `ASC_API_KEY_P8` | both | Base64 of the API key (`base64 -i AuthKey_XXXX.p8`) |
| `MACOS_CERT_P12` | Developer ID | Base64 of the *Developer ID Application* certificate (`.p12`) |
| `MACOS_CERT_PASSWORD` | Developer ID | Password of the `.p12` |

Without the certificate and team the Developer ID job refuses to publish, unless a manual run opts in to an **unsigned** build with `allow_unsigned` (the release is then labelled as such). Without the API key the Developer ID build is signed but not notarized, and the App Store job fails.

Secrets are exposed only to the steps that need them, and the temporary keychain and key files are removed at the end of every run.

## The Controls extension

`ChitarraTuneControls.appex` (`com.chitarratune.app.controls`) is signed like the app, with its own entitlements (`Config/ChitarraTuneControls.entitlements`): the same Enhanced Security keys, the macOS App Sandbox, no network and no resources at all, not even the microphone. The intent it triggers runs in the app.

## Gatekeeper

An unsigned or non-notarized build shows "Apple cannot check it for malicious software". Verify the published SHA-256, then use **Right-click → Open** once.
