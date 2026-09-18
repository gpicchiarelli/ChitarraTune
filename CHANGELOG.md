# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

Version 2.0 is a ground-up rewrite, and the first release for the App Store (iPhone, iPad and Mac, free, unlisted) alongside the notarized Developer ID build for the Mac.

### Changed

- **Architecture.** The code is now a local Swift package, `ChitarraTuneKit` (`TunerCore`, `TunerAudio`, `TunerFeature`), under a single multiplatform SwiftUI app. It replaces `ChitarraTuneCore`, `Apps/Shared` and the separate macOS and iOS targets.
- **Pitch detection.** YIN now evaluates the difference function through an FFT cross-correlation (Accelerate) instead of a direct `O(N · lags)` loop, with octave-error correction and a search range that follows the tuning and A4.
- **Capture.** `AVAudioEngine` replaces `AVCaptureSession`; capture is an actor, samples arrive in order through an `AsyncThrowingStream`, and a slow consumer never builds a backlog.
- **Input devices.** Hot-plug detection is event-driven (Core Audio listener blocks on macOS, route-change notifications on iOS) instead of polling every two seconds.
- **Session control.** A generation counter cancels stale starts, and route changes restart capture automatically (up to three times).
- **Siri and Shortcuts.** App Intents reach the running tuner through `AppDependencyManager`. *Start tuning* opens the app, because a microphone needs the foreground.
- **Requirements.** macOS 26, iOS 26 and iPadOS 26; Xcode 26. Build settings moved to `Config/*.xcconfig`.
- **Tests.** Moved to Swift Testing inside the package, covering the signal path with synthetic signals and the presentation layer with test doubles.

### Added

- **More accurate on real strings.** Steel strings are slightly inharmonic, which pulled YIN's reading one to four cents sharp (up to eight on a stiff string). A per-string streaming band-pass and a second period measurement on it now measure the fundamental itself; the typical error on a modelled string is under one cent. As a note dies away the reading can no longer jump an octave (or to another string).
- A physically informed string model (inharmonicity, pluck position, phone-microphone roll-off, pick and room noise, mains hum) and accuracy tests for every tuning and string; a corpus directory for real recordings that become regression tests.
- A screen that explains why the tuner needs the microphone before the system asks.
- Listening resumes by itself after a phone call or Siri, and restarts after a reset of the media services.
- A *Start Tuning* control for Control Center, the Lock Screen and the Action Button (iPhone, iPad) and Control Center and the menu bar (Mac).
- A new app icon for Liquid Glass, made in Icon Composer: the guitar is the needle of a meter, pointing at the green in-tune mark of a scale, in default, dark, clear and tinted appearances.
- App Store listing in English and Italian, review notes, support page, updated privacy policy, device test plan and submission runbook.
- Release workflow for the App Store: iOS/iPadOS and macOS archives with cloud-managed signing, uploaded to App Store Connect; version bump and release-notes scripts.
- Ten tunings (Standard, Half step down, Full step down, Drop D, Drop C, DADGAD, Open D, Open G, Open E, Open A).
- Dial and bar gauges; English or fixed-do solfège note names; haptic feedback; an idle timeout that stops listening after a period of silence.
- One tuner per window on macOS, each with its own input and tuning.
- Low Power Mode and thermal-state awareness (lower analysis rate).
- `ITSAppUsesNonExemptEncryption = NO`, and a permission text that says audio is never recorded or sent anywhere.

### Fixed

- Demo mode could have written into, and then wiped, the real preferences if its settings suite could not be opened; it now falls back to a private suite.
- Accessibility, found by Xcode's audit now run on every screen: the *Auto* chip had an 18-point touch target; secondary text, white text on tinted glass in Dark Mode and green and amber text did not reach 4.5:1 contrast; the string chips shrank their labels instead of growing with Dynamic Type; the landscape layout and the failure screen clipped text at the largest sizes; a disabled *Reset* button was unreadable.
- Two sheets on the same view meant the Settings sheet shadowed any other; the explanation screen and Settings now share one.
- macOS: automatic termination is off, so a relaunch never reuses an invisible, windowless process; the About and License windows no longer reopen at launch. The string chips, the gauge and the input menu keep proper roles and actions for VoiceOver on the Mac.
- The demo mode no longer shows third-party product names.
- A `NaN` A4 stored in the preferences no longer crashes the engine (it used to survive the clamp and trap on the first audio chunk); it now falls back to 440 Hz.
- On an audio interface the tuner now listens to the loudest input channel instead of always channel 0, so a guitar plugged into input 2 is heard.
- On iOS a start requested from the microphone permission prompt is no longer cancelled: the tuner stops when the app is in the background, not merely inactive.
- The engine rejects non-finite or absurd sample rates instead of trapping in an integer conversion.

### Security

- Hardened Runtime and Xcode Enhanced Security, with the sandbox limited to audio input and no network access.
- The Core Audio input enumeration no longer reads a variable-size `AudioBufferList` into a fixed-size local, and capture no longer parses raw sample-buffer memory.
- The A4 reference is clamped to 415–466 Hz.

### Quality gate

- Line coverage is 100 % in TunerCore, TunerAudio and TunerFeature. The code that drives the real microphone and Core Audio devices lives in `TunerAudio/Hardware/`, is the only exclusion, and a policy test keeps that folder to its four adapters. Buffer conversion and permission mapping moved out of it so they are tested.
- Removed dead code found on the way (an unreachable `fail` overload, a `rangeChanged` flag that was always true, fallbacks that could never run) and made the power state injectable.
- UI tests on iPhone, iPad and Mac in CI, with the accessibility audit of every screen in light and dark appearance, landscape and the largest text size; the full DSP accuracy matrix in an optimised build.
- New policy tests: WCAG contrast of every colour in every appearance, App Store metadata limits and claims, the Controls extension's entitlements, every string catalog complete in both languages.
- The pre-push hook runs the gate before anything leaves the machine, and CI repeats it (Gate, Lint, CodeQL) on GitHub. The gate builds without warnings, runs SwiftLint in strict mode, enforces per-module coverage floors and runs every test. `main` itself only refuses deletion and force-pushes.
- New test families: hostile input and fuzzing of the DSP, checks of the documented numbers against the code, smoke tests of the system audio layer, and repository-policy tests (no network APIs, entitlements, privacy manifest, pinned actions, complete translations, README matching the implementation).
- `Scripts/verify.sh` runs the same checks locally; `.githooks/pre-push` runs it automatically once enabled.

### Repository

- CI rebuilt for the new layout: package tests, macOS and iOS Simulator builds, CodeQL, SwiftLint. Every action is pinned to a full commit SHA, workflows run read-only unless they must write, and Dependabot keeps the pins current.
- The release workflow now signs inside `xcodebuild`, verifies the Hardened Runtime flag and the entitlements, notarizes a real archive, publishes a build-provenance attestation, and refuses to release from a commit that is not on `main`.
- Added a security policy, contributing guide, issue forms, pull request template and code owners.
- Rewrote the architecture, platforms, signing, compliance and accessibility documents to match the code.

### Removed

- The legacy `ChitarraTuneCore` and `Apps/` sources, the XCTest unit-test target and the generated `VersionInfo.swift` (version data now comes from build settings).

## [1.0.0] and earlier

Initial releases: guitar tuner for macOS and iOS with several tunings, A4 calibration, Siri and Shortcuts, English and Italian localization, and Italian note names (Do, Re, Mi).

