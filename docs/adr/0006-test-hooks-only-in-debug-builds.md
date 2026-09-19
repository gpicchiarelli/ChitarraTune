# ADR 0006: Test hooks only in Debug builds

Status: Accepted (2026-09-19)

## Context

UI tests and App Store screenshots run the app with a synthetic guitar and a faked microphone permission, selected by launch arguments. In a shipping build the same switches would let anything that can launch the app change what it measures or pretend a permission.

## Decision

1. Launch arguments that change behavior (`-demo`, `-autostart`, `-demoPermission`, `-demoAppearance`) MUST be honoured only in Debug builds; a Release build MUST ignore them.
2. The scheme MUST test with the Debug configuration and archive with Release.
3. No other test-only switch (environment variable, user default, hidden gesture) MAY exist in the app.

## Consequences

- UI tests and screenshots exercise a Debug build; everything they rely on is absent from what users run.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (test hooks) checks `App/Platform/FocusedValues+LaunchOptions.swift` and `ChitarraTune.xcodeproj/xcshareddata/xcschemes/ChitarraTune.xcscheme`.
