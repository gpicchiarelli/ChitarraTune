# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

Version 2.0 is a ground-up rewrite. Work in progress: the package is complete and tested, the app layer is being finished.

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

- Ten tunings (Standard, Half step down, Full step down, Drop D, Drop C, DADGAD, Open D, Open G, Open E, Open A).
- Dial and bar gauges; English or fixed-do solfège note names; haptic feedback; an idle timeout that stops listening after a period of silence.
- One tuner per window on macOS, each with its own input and tuning.
- Low Power Mode and thermal-state awareness (lower analysis rate).
- `ITSAppUsesNonExemptEncryption = NO`, and a permission text that says audio is never recorded or sent anywhere.

### Fixed

- A `NaN` A4 stored in the preferences no longer crashes the engine (it used to survive the clamp and trap on the first audio chunk); it now falls back to 440 Hz.
- On an audio interface the tuner now listens to the loudest input channel instead of always channel 0, so a guitar plugged into input 2 is heard.
- On iOS a start requested from the microphone permission prompt is no longer cancelled: the tuner stops when the app is in the background, not merely inactive.
- The engine rejects non-finite or absurd sample rates instead of trapping in an integer conversion.

### Security

- Hardened Runtime and Xcode Enhanced Security, with the sandbox limited to audio input and no network access.
- The Core Audio input enumeration no longer reads a variable-size `AudioBufferList` into a fixed-size local, and capture no longer parses raw sample-buffer memory.
- The A4 reference is clamped to 415–466 Hz.

### Quality gate

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

