# ADR 0007: Concurrency model

Status: Accepted (2026-09-19)

## Context

Audio arrives on a real-time thread, analysis must not block it, and the UI lives on the main actor. Data races here would corrupt measurements silently.

## Decision

1. Every target compiles in the Swift 6 language mode with complete strict concurrency; warnings are errors.
2. The audio tap closure MUST NOT touch actor state: it copies the samples and yields them into a stream.
3. Capture (`EngineAudioCapture`) and analysis (`TunerProcessor`) are actors; presentation models are `@MainActor`. Only `TunerFrame`s cross to the main actor.
4. Streams buffer only the newest elements: a slow consumer loses frames, never builds a backlog, and never makes the analysis skip samples.
5. `@unchecked Sendable` MUST NOT be used. `nonisolated(unsafe)` and `MainActor.assumeIsolated` MUST be limited to the audited uses listed in the enforcing test, each with a comment explaining why it is safe.
6. Waiting for a condition MUST be event-driven (streams, notifications, observation): no polling loops and no `Thread.sleep`, in the app, the package or the UI tests. A timed delay is allowed only when time itself is the point (the demo guitar's real-time pacing, a confirmation that fades after two seconds).

## Consequences

- Adding an unsafe escape hatch requires changing the allowlist in a reviewed test.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (Swift 6 and complete strict concurrency in the build settings).
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (concurrency escape hatches).
- `Scripts/verify.sh` and `.github/workflows/ci.yml` (warnings as errors).
