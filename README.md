# ChitarraTune

<p>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml"><img alt="Build" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml"><img alt="SwiftLint" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gpicchiarelli/ChitarraTune?include_prereleases&label=release"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/gpicchiarelli/ChitarraTune/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gpicchiarelli/ChitarraTune?color=blue"></a>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple">
</p>

macOS guitar tuner built with Swift/SwiftUI. Pure‑Swift DSP (YIN/CMNDF), real‑time indicators, Auto/Manual modes, alternate tunings, and A4 calibration. Localized in English and Italian.

—

IT: Accordatore per chitarra per macOS in Swift/SwiftUI. DSP in puro Swift (YIN/CMNDF), indicatori in tempo reale, modalità Auto/Manuale, accordature alternative e calibrazione A4. Localizzato in Italiano e Inglese.

## Features · Caratteristiche
- Pitch detection: YIN with parabolic refinement; frequent updates; adaptive smoothing.
- Tunings: Standard, Drop D, DADGAD, Open G, Open D, Half‑step down.
- Modes: Auto (string recognition) / Manual (select string from preset).
- UI: horizontal bar with ±5 cents green zone and color feedback.
- Calibration: A4 415–466 Hz.
- Input devices: pick microphones/interfaces with persistence and refresh.
- Privacy/Security: sandboxed, mic permission; on‑device processing only.
- License: BSD 3‑Clause.

Website · Sito: https://gpicchiarelli.github.io/ChitarraTune/

## Requirements · Requisiti
- Xcode 15+
- macOS 12+

## Build
1) Open `ChitarraTune.xcodeproj` in Xcode 15+ and run the `ChitarraTune` scheme on macOS.

Notes · Note
- Core DSP lives in `ChitarraTuneCore` (local Swift Package).
- App icons: `scripts/generate_appicons.sh` (see `doc/appicon.md`).
- Version info is embedded at build time (git tag + short SHA). The About window can copy it.

## Tests / CI
- SwiftPM: `swift test --parallel --enable-code-coverage`
- UI (XCUITest): run on macOS with audio prompts disabled via `UITEST_DISABLE_AUDIO=1`.
  Example: `xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -destination platform=macOS CODE_SIGNING_ALLOWED=NO test`
- The UI tests are resilient: title is always checked; mode control is validated when exposed (may be skipped on some headless setups).
- GitHub Actions CI runs SwiftPM + XCUITest and publishes coverage.

## Releases · Rilasci
- Create a tag like `v1.2.3` and push it.
- The Release workflow runs tests, builds a Release `.app`, stamps version from the tag/commit, zips it, and attaches it to the GitHub Release.
- Output file: `ChitarraTune-<version>-macOS.zip` with a `.sha256` checksum.
- Local packaging: run `scripts/package_app.sh v1.2.3` to reproduce the same artifact locally (tests must pass).

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
- Bug page (IT/EN): https://gpicchiarelli.github.io/ChitarraTune/bug.html
