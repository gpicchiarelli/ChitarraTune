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

The [release workflow](.github/workflows/release.yml) runs on a `vX.Y.Z` tag or manually, and only from a commit that is on `main`. It:

1. runs the package tests,
2. builds with Manual signing using your Developer ID Application certificate,
3. verifies the signature, the Hardened Runtime flag and that the sandbox and audio-input entitlements are present,
4. notarizes with `notarytool` and staples the ticket,
5. zips the app, writes a SHA-256 checksum and a build-provenance attestation,
6. creates the GitHub Release.

Configure these repository secrets:

| Secret | Content |
| --- | --- |
| `MACOS_CERT_P12` | Base64 of the *Developer ID Application* certificate (`.p12`) |
| `MACOS_CERT_PASSWORD` | Password of the `.p12` |
| `MACOS_TEAM_ID` | Your Apple Developer Team ID |
| `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID` | App Store Connect API key identifiers |
| `NOTARY_API_KEY_P8` | Base64 of the API key (`.p8`) |

Without the first three the workflow refuses to publish. A manual run can opt in to an **unsigned** build with the `allow_unsigned` input; the release is then labelled as unsigned. Without the notary secrets the release is signed but not notarized, and the workflow says so.

Secrets are exposed only to the steps that need them, and the temporary keychain and key files are removed at the end of the run.

## Gatekeeper

An unsigned or non-notarized build shows "Apple cannot check it for malicious software". Verify the published SHA-256, then use **Right-click → Open** once.
