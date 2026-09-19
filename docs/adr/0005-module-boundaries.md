# ADR 0005: Module boundaries

Status: Accepted (2026-09-19)

## Context

The measurement must be testable without a microphone, the audio layer without a screen, and the presentation without either. That only holds if each layer depends on nothing above it.

## Decision

1. `TunerCore` (domain and DSP) MUST import only `Foundation` and `Accelerate`: no audio I/O, no UI, no logging, no clocks.
2. `TunerAudio` (capture, permission, input devices) MUST NOT import UI frameworks or `TunerFeature`.
3. `TunerFeature` (presentation models) MUST NOT import UI frameworks (`SwiftUI`, `UIKit`, `AppKit`).
4. UI code lives only in the app and the Controls extension. The extension's own code MUST import only `AppIntents`, `SwiftUI` and `WidgetKit`; it links `TunerFeature` solely for the intent it shares with the app (`Shared/StartTuningIntent.swift`, which imports only `AppIntents` and `TunerFeature`), which always runs in the app. The extension has no microphone entitlement (ADR 0003).
5. Code that only real hardware can execute lives in `Sources/TunerAudio/Hardware/`, which is the only part of the package excluded from the coverage gate and holds only thin system calls.
6. Demo and preview data sources (`SimulatedAudioCapture`, `FixedSources.swift`) MAY ship in the package, but only Debug builds of the app can select them (ADR 0006).

## Consequences

- The whole signal path runs in unit tests with synthetic and recorded signals.
- A new dependency between layers needs this ADR superseded, not just an import.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (module imports) checks every import of every module against its allowlist.
- `Scripts/coverage-gate.sh` and `Scripts/coverage-thresholds.json` (100 % outside `Hardware/`).
