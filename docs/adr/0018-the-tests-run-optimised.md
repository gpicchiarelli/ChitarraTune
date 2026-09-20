# ADR 0018: The tests run optimised

Status: Accepted (2026-09-20)

## Context

This is a measuring instrument: most of what its tests do is arithmetic. `GoldenReadingsTests` renders every string of every tuning at three sample rates, as a harmonic tone and as a plucked inharmonic string, and compares every frame the engine produces against a frozen file. `RealisticSignalTests` walks the same matrix with noise and hum. That work is a few hundred thousand floating-point operations per case, and Swift at `-Onone` does not optimise a single one of them.

Measured on this machine, warm, same tests, same machine, only the optimisation level changed:

| | `-Onone` | `-O` |
| --- | ---: | ---: |
| Golden readings, every frame of every reference signal | 162.5 s | 0.94 s |
| The Low Power analysis rate | 152.3 s | 0.82 s |
| `Scripts/coverage-gate.sh`, whole suite, coverage included | 3 min 28 s | 25 s |

Nothing about the gate was weakened to get that. The coverage export counts exactly the same lines in both configurations — TunerAudio 324, TunerCore 960, TunerFeature 570 — so the 100 % floor means what it meant. The package sources contain no `assert()`, which `-O` removes, and no `#if DEBUG`, which `-O` compiles out; the checks that do exist are `precondition` and `fatalError`, and array-bounds and integer-overflow traps, all of which `-O` keeps. `-Xswiftc -enable-testing` keeps `@testable import` working.

The project already knew this: `.github/workflows/ci.yml` runs the accuracy matrix in a separate optimised job because it is "too slow for a debug build on every push". The conclusion was applied on GitHub and not on the machine where the gate is actually the gate ([ADR 0017](0017-build-artifacts-disk-and-reuse.md)).

A slow gate is not only an inconvenience. A three-and-a-half-minute pre-push hook is one a tired person skips with `--no-verify`, and a check that is skipped verifies nothing.

## Decision

1. The package tests MUST be compiled optimised: `-c release -Xswiftc -enable-testing`. `Scripts/coverage-gate.sh` does this by default, and `CONFIGURATION=debug` is available for a debugger session or to compare the two.
2. Every command that builds the package for the gate — `Scripts/verify.sh`, `Scripts/coverage-gate.sh`, the `kit` job of `.github/workflows/ci.yml` — MUST pass an identical set of flags. SwiftPM plans one build per set of flags, so a single character of difference compiles the package a second time.
3. Test sources are held to `-Xswiftc -warnings-as-errors` like every other source.
4. A change that makes the gate materially slower MUST say so in its commit message with the measurement, the way this record does. There is no automatic budget: the number that matters is what somebody is willing to wait for before a push, and only a person can judge it.
5. The optimised suite MUST NOT be the only thing an accuracy claim rests on. The full matrix (`CHITARRA_FULL_DSP=1`) and the real-time budgets keep their own CI job, on an unloaded runner, because a timing assertion measured beside a saturated test suite measures the suite ([ADR 0008](0008-measurement-integrity.md)).

## Consequences

- The pre-push gate goes from three and a half minutes to about half a minute, which is the difference between running it and reasoning about whether to.
- A crash inside an optimised test gives a worse backtrace. `CONFIGURATION=debug Scripts/coverage-gate.sh` is the way back, and it is in the script's `--help`.
- `assert()` would now be compiled out of the package, so it must not be used for anything the tests rely on. `precondition` is the one that survives, and it is what the sources already use.
- Rule 4 is a rule a machine cannot check, and it is written as prose on purpose. The reviewer checks it when a test that takes real time is added.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ScriptPolicyTests.swift` checks that the coverage gate compiles optimised with testing enabled, that it still offers the debug configuration, and that `Scripts/verify.sh` builds with the same flags.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` checks that the `kit` job of `.github/workflows/ci.yml` builds with those flags too, and that the full accuracy matrix keeps a job of its own.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` keeps the coverage floors at 100 %, which is what makes the two configurations comparable.
