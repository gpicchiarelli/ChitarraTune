# ChitarraTune

<p>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml"><img alt="Build" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml"><img alt="SwiftLint" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gpicchiarelli/ChitarraTune?include_prereleases&label=release"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/gpicchiarelli/ChitarraTune/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gpicchiarelli/ChitarraTune?color=blue"></a>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20iPadOS-1f6feb?logo=apple">
</p>

Modern guitar tuner for **macOS**, **iPhone**, and **iPad** built with Swift 6/SwiftUI. Features pure‑Swift DSP (YIN/CMNDF), real‑time indicators, Auto/Manual modes, alternate tunings, and A4 calibration. Fully localized in English and Italian.

—

IT: Moderno accordatore per chitarra per macOS, iPhone e iPad in Swift 6/SwiftUI. DSP in puro Swift (YIN/CMNDF), indicatori in tempo reale, modalità Auto/Manuale, accordature alternative e calibrazione A4. Completamente localizzato in Italiano e Inglese.

## Features · Caratteristiche
- **Swift 6**: Built with latest Swift concurrency and strict concurrency checking
- **Pitch Detection**: YIN algorithm with parabolic refinement, real-time updates, adaptive smoothing
- **Tunings**: Standard, Drop D, DADGAD, Open G, Open D, Half-step down
- **Modes**: Auto (string recognition) / Manual (select string from preset)
- **Modern UI**: Clean interface with horizontal tuning bar, ±5 cents green zone, color feedback
- **Calibration**: A4 reference frequency 415–466 Hz with fine adjustment
- **Audio Devices**: Real-time device detection, microphone/interface selection with persistence
- **Privacy/Security**: Sandboxed, microphone permission, on-device processing only
- **Accessibility**: Full VoiceOver support with proper labels and identifiers
- **License**: BSD 3-Clause

## Requirements · Requisiti
- Xcode 16+ (Swift 6)
- **macOS** 12.0+
- **iOS / iPadOS** 16.0+ (iPhone e iPad)

Per i dettagli delle piattaforme, target e build: [PLATFORMS.md](PLATFORMS.md).

## App Store readiness · Pronto per App Store
- **License**: BSD 3-Clause; copyright in `LICENSE` and in the app (About / License panel).
- **Bundle ID**: `com.chitarratune.app` (change in Xcode when you register your own).
- **Metadata**: `Info.plist` includes `NSHumanReadableCopyright`, category Music, microphone usage description (localized).
- **Sandbox**: App uses only App Sandbox + microphone input (no network, no file access outside container).
- **Code signing**: Disabled by default so you can build without an Apple Developer account. When you have one, set your Team in Xcode (Signing & Capabilities) and use Developer ID for distribution or App Store Connect for the Mac App Store.

## Build
1. Open `ChitarraTune.xcodeproj` in Xcode.
2. **macOS**: run the **ChitarraTune** scheme (destination: My Mac).
3. **iPhone / iPad**: run the **ChitarraTune iOS** scheme (destination: iPhone or iPad simulator, or a device).

**No Apple Developer account (current setup)**
- The project is set to **not sign** (`CODE_SIGN_IDENTITY = -`). Build and run as usual.
- First launch: if macOS blocks the app, use **Right‑click → Open** once.

**With Apple Developer account (for distribution / App Store)**
- Target **ChitarraTune** → **Signing & Capabilities** → set your **Team** and enable **Automatically manage signing** (or use Manual + your Developer ID / distribution certificate).
- For notarization and Mac App Store, use the secrets described in **Releases** below.

**CLI (no signing)**
- `xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`

Notes · Note
- Il progetto è **solo Xcode** (nessun Swift Package separato). Il codice core è in `ChitarraTuneCore/`.
- Version info is embedded at build time (git tag + short SHA). The About window can copy it.

## Tests / CI
- **UI (XCUITest)**: run in Xcode or `xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` (audio prompts disabled via `UITEST_DISABLE_AUDIO=1`).
- GitHub Actions CI runs Xcode build and (optionally) UI tests.

## Releases · Rilasci
- Create a tag like `v1.2.3` and push it.
- The Release workflow runs tests, builds a Release `.app`, stamps version from the tag/commit, zips it, and attaches it to the GitHub Release.
- Output file: `ChitarraTune-<version>-macOS.zip` with a `.sha256` checksum.
- Local packaging: build Release in Xcode, then zip the `.app` from the build products.
  - The script attempts local signing (Apple Development if available; fallback to ad‑hoc), then zips and creates `.sha256`.

### macOS Gatekeeper / Notarization
- Unsigned builds trigger “Apple cannot check for malicious software”. You can bypass once with Right‑click → Open.
- To publish signed and notarized releases, add these GitHub Secrets and re‑run the Release workflow:
  - `MACOS_CERT_P12`: base64 of your Developer ID Application certificate (.p12)
  - `MACOS_CERT_PASSWORD`: password for the .p12
  - `CODESIGN_IDENTITY` (optional): full identity string, e.g. `Developer ID Application: Your Name (TEAMID)`
  - `MACOS_TEAM_ID` (optional): your Team ID
  - `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, `NOTARY_API_KEY_P8`: App Store Connect API key (p8 base64)
- When these are set, the Release workflow signs (hardened runtime), submits for notarization, staples the ticket, and then zips the .app.

## Privacy · Privacy
Uses the microphone only to compute pitch locally. No data leaves the device.

## License · Licenza
BSD 3‑Clause — see `LICENSE`.

## Support · Supporto
- Issues: https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose
