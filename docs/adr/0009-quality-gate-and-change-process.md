# ADR 0009: Quality gate and change process

Status: Accepted (2026-09-19)

## Context

Maintainers do not use pull requests: changes go straight to `main`. The only filter is the gate, so the gate must be complete and impossible to skip by accident.

## Decision

1. Maintainers push directly to `main`; no other branches are kept. An outside contribution arrives as a pull request from a fork, passes the same gate, and a maintainer lands it on `main`.
2. Before every push the pre-push hook runs `Scripts/verify.sh`: strict SwiftLint, a warning-free package build, all package tests and the coverage gate.
3. CI MUST run the same checks plus every app build (macOS and iOS, Debug and Release with `arm64e`), the optimised DSP job and the UI tests on iPhone, iPad and Mac, and report one aggregate `Gate` check.
4. Line coverage MUST be 100 % for `TunerCore`, `TunerAudio` and `TunerFeature`, excluding only `Sources/TunerAudio/Hardware/`.
5. A change to behaviour covered by an ADR MUST update or supersede that ADR in the same commit; a change to documented numbers MUST update the documents in the same commit.
6. The `main` ruleset forbids deletion and force-pushes, with no bypass actors.

## Consequences

- A red gate blocks nothing on GitHub by itself; the discipline is the hook and not pushing on red.

## Enforcement

- `.githooks/pre-push`, `Scripts/verify.sh`, `Scripts/coverage-gate.sh`.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` and `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (coverage thresholds).
