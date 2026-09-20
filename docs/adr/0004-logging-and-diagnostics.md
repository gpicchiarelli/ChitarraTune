# ADR 0004: Logging and diagnostics

Status: Accepted (2026-09-19)

## Context

Logs are how a tuner that misbehaves on someone's device gets fixed: *Copy Diagnostics* puts the app's recent log in a bug report. Anything logged publicly can end up in such a report, so what is logged, and how, is a privacy decision.

## Decision

1. The app MUST log only through Unified Logging (`TunerLog`), one subsystem, one category per concern. `print` and `NSLog` MUST NOT be used.
2. Dynamic values are private by default. Only enum case names, numbers, stream metadata and build identifiers MAY be `.public`.
3. Errors MUST be logged publicly as domain and code only (`EngineAudioCapture.describe(_:)`); `localizedDescription` MUST NOT be logged publicly, because it can quote device names or paths.
4. Device names and UIDs MUST be `.private`.
5. Audio content MUST NOT be logged in any form (ADR 0002).
6. Diagnostics MUST stay on the device: MetricKit payloads are summarized into the log, never sent anywhere; the user decides whether to paste a report.

## Consequences

- A diagnostics report shows what happened (states, codes, stream statistics) without identifying the user's equipment.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (logging rules) scans the sources.
- `Packages/ChitarraTuneKit/Tests/TunerFeatureTests/SystemAudioTests.swift` checks that a logged error carries domain and code only.
