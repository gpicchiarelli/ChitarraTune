# ADR 0012: Windows and listening sessions

Status: Accepted (2026-09-19)

## Context

A tuner holds the microphone. On the Mac each window can tune a different instrument; on iPhone and iPad the app has one audio input for the whole process. Siri, Shortcuts, Control Center and the Dock menu start and stop listening without a window of their own, so they must know which tuner they mean, and must never leave the microphone running with nothing on screen.

## Decision

1. iPhone and iPad MUST run a single scene: the manifest in `Config/Info.plist` declares `UIApplicationSupportsMultipleScenes = false`, and Xcode MUST NOT generate a manifest that overrides it.
2. On the Mac each window owns one tuner, with its own input and tuning; closing a window stops its tuner and releases every model but the primary one.
3. The active tuner, the one system-wide entry points act on, MUST be the focused window's, and only an open window's: closing the focused window hands over to another open one.
4. An entry point that starts listening with no tuner window open MUST open one first.
5. Quitting releases the microphone first, but MUST NOT wait for it longer than two seconds.
6. iOS stops listening when the app moves to the background; the Mac keeps listening while the window is open.

## Consequences

- A second iPad window is not offered: it could only mirror the same tuner.
- The hub, not the views, knows which windows are open and which is focused.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (windows and sessions) checks the scene manifest, its generation setting, the quit timeout, that rule 4 is kept in `TunerHub.startOnVisibleTuner`, and that every entry point which starts listening goes through it rather than keeping its own copy of the rule.
- `Packages/ChitarraTuneKit/Tests/TunerFeatureTests/TunerSettingsTests.swift` (the hub: focus, open windows, closing the focused one).
- `ChitarraTuneUITests/ChitarraTuneUITests.swift` (the app launches and listens on iPhone, iPad and Mac).
