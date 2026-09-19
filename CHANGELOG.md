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
- **Release readiness on every push.** `Scripts/release-check.sh` builds the Mac app exactly as a release and checks it the way notarization and App Review would; CI runs it on every push and the release workflow on its signed build before notarizing ([ADR 0013](docs/adr/0013-release-readiness.md)). It found that a Release build signed for development carried `get-task-allow`, which notarization rejects: Release builds no longer inject development entitlements. CI runners are pinned to explicit images.
- **Architecture decision records.** Eleven binding ADRs (`docs/adr/`) cover privacy, platform security, logging, module boundaries, test hooks, concurrency, measurement integrity, the quality gate, the supply chain, localisation and accessibility. Each is enforced by a test; new policy tests scan every source file (no audio can be written, exported or shared; no error descriptions or device identities in the public log; module imports per layer; audited concurrency escape hatches).
- Field-testing tools. The diagnostics log records what the device really delivers (sample rate, callback sizes, analyses per second, lost audio), never the audio itself. `Scripts/add-recording.sh` adds a recording made with a separate recorder to the test corpus, with a reference tuner's reading as ground truth; corpus entries may state the A4 they were tuned to.
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

- iPad: one window. Several windows all showed the same tuner, and minimising or closing one stopped listening in the others.
- Mac: Siri, Shortcuts, the Dock menu and Control Center act on the focused window's tuner, not on the one opened last; closing the focused window hands over to another open one, and *Start* from the Dock with no tuner window open opens one first instead of listening with nothing on screen.
- Mac: quitting waits at most two seconds for the audio to stop, so ⌘Q always quits even if Core Audio blocks (an interface unplugged while it stops).
- A lower string played softly after a higher one an octave or two above (D3 → D2 in Drop D, with no attack to announce it) was read as the higher string; the engine now checks that the lower note is really absent before treating the detection as an octave error. No golden reading changes.
- *Start Tuning* declares `supportedModes = .foreground` instead of the deprecated `openAppWhenRun`.
- *Copy Diagnostics* includes a one-line summary of the crashes and hangs MetricKit reported for earlier sessions, whose logs are no longer readable after a crash.
- Copying a `TuningEngine` now copies its string filters: they were reference types, so a copy shared their state and feeding one engine disturbed the other. The refinement reports failure as `nil` instead of returning its input. Neither change moves any golden reading.
- Release builds ignore the demo and test launch arguments; only Debug builds (UI tests, screenshots) honour them.
- Logged errors carry their domain and code only: an error description can quote a device name and would have been public in *Copy Diagnostics*.
- Shortcuts' *Choose Input* lists the inputs the tuner itself sees, instead of querying the hardware separately.
- The Mac window-close observer is removed when its view goes away.

- VoiceOver now says notes as words in the user's language ("E flat, octave 2", "Mi bemolle, ottava 2") instead of leaving "Mi♭2" to the speech engine, and the readout's spoken value is a localized format.
- Shortcuts shows each tuning's strings in the user's notation (solfège in Italian) instead of hard-coded English letters.
- The Space key no longer starts or stops listening from the Listen button: with Full Keyboard Access it must activate the focused control. ⌘L remains.
- The string menu follows the current tuning's string count, the reference-pitch slider labels come from the supported range, and "Copy diagnostics" confirms every copy, not only the first.
- **Mains hum no longer biases the low strings, and Low Power Mode is as accurate as normal.** Hum inside a low string's refinement band beat with the fundamental and pulled the reading flat; averaging hid it only when the analyses happened to fall on different phases of the beat. At the Low Power rate (one analysis every 45 ms) a low D read up to 2.5 cents flat on the reference signals and 10 cents with strong 60 Hz hum. The string filters now notch the 50 and 60 Hz families out of the band, the refinement waits for the filters to settle after each attack (keeping the string's known correction meanwhile), a change of correction moves the averaged history with it, and smoothing is defined in time rather than per analysis. On the 132 reference signals the per-note median error falls from 0.38 to 0.16 cent (mean 0.28 → 0.18, worst 1.02 → 0.49); at the Low Power rate the worst note falls from 2.48 to 0.59 cent; with doubled 50/60 Hz hum the worst low string falls from 10.2 to 1.6 cents. One regression, within its limit: very stiff strings read 0.85 cent typical instead of 0.66 (their worst case falls from 6.4 to 3.8). The engine costs 0.9 % of real time instead of 0.6 %.
- **Measurements no longer depend on how the device slices audio.** The engine analysed once per callback, so with 100 ms callbacks one analysis counted as four towards "in tune" and the smoothing ran four times slower than with 23 ms ones. It now analyses at fixed sample positions, every 25 ms, whatever the callback size; a test feeds the same performance in chunks from 17 to 8 192 samples and requires identical frames. On the reference signals the worst note's median error drops from 1.9 to 1.0 cent and the mean from 0.29 to 0.28 cent.
- The per-string filters run in double precision, sample by sample, instead of `vDSP_biquad` in single precision, whose output changed with the chunk boundaries and the CPU. Their documented attenuation of the third partial is corrected: 22 dB on pitch, at least 15 dB across the ±300 cent window (not 20 dB).
- The signal level (noise gate, attack detection) is now measured over a fixed 46 ms instead of 2 048 samples, so the gate behaves the same at every sample rate. Only the level value changes at 48 and 96 kHz; no frequency or cents value changes anywhere in the golden readings.
- Demo mode tunes its synthetic guitar to the user's reference pitch instead of always 440 Hz.
- The gauges draw their green zone from the engine's in-tune threshold instead of a repeated ±5.
- After tuning a low string, playing the string one or two octaves above it (E2 → E4 in standard; D2 → D3 → D4 in Drop D, DADGAD and Open D) kept showing the low string for as long as the new one sounded. The octave-continuity rule now folds a detection down only while the followed note's fundamental is still measurably present.
- Lost audio (a dropped buffer, an overloaded main thread) could splice two unrelated stretches of signal into one analysis window. The audio loop now runs off the main actor, and a gap in the device timeline discards the history.
- Closing a tab of a tabbed macOS window no longer discards the tuner of a *hidden* tab: a tuner is released only when its window is really closed.
- On iOS, listing the audio inputs no longer changes the audio session's category.
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

- Microphone capture is now tested without a microphone: `AVAudioEngine` in manual rendering mode feeds it a synthetic signal, so the tap, channel selection, sample times, teardown and route changes run in CI. Only system calls (session setup, device routing, starting the real engine) remain in the uncovered hardware boundary.
- `eventually` in the tests is event-driven (Observation) instead of polling every 5 ms; the feature tests went from about 60 s to 2.5 s. The UI tests wait on the screen they need instead of sleeping.
- SwiftLint is stricter (force unwrapping, implicit returns, line length 160, shorter functions and more) and now also covers the Controls extension and the shared sources.
- Pointer authentication (arm64e) for everything that ships: both release channels pass it on the xcodebuild command line, where it also reaches the SwiftPM targets, and verify the binaries with `lipo`; CI builds and checks macOS and iOS arm64e on every push.
- A golden-readings test freezes every frame the engine produces for 132 reference signals (every string of every tuning, detuned, at 44.1, 48 and 96 kHz, harmonic and inharmonic plucked), and an independent accuracy envelope requires the right string everywhere, a median error of at most 2 cents per note and 0.5 cent overall (today: 0.34 cent). A refactor must reproduce the golden readings (discrete values exactly, continuous ones within 0.02 cent, since float rounding differs between CPUs); a deliberate change must regenerate them and say why.
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

