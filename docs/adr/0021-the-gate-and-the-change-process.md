# ADR 0021: The gate and the change process

Status: Accepted (2026-09-20)

## Context

This supersedes [ADR 0009](0009-quality-gate-and-change-process.md), which was right about the shape of the gate and wrong about two things that a day of measurement made plain.

Its rule 3 required CI to run "the UI tests on iPhone, iPad and Mac" on every push. The Mac ones cannot pass: a macOS 27 minimum means the app will not launch on GitHub's generally available `macos-26` image, and the only image running macOS 27 is the `xcode-27` preview, whose virtual GPU has no shader slice for SwiftUI's renderer (`unable to find air64_v27 slice`, RenderBox), so the window never draws and every wait times out. They were therefore made unable to stop the gate — correctly — and then kept running on every push anyway.

That is a machine producing scrap on a schedule. The evidence is not a judgement call: `ui-Mac` result-bundle artifacts, which are uploaded only when a test fails, exist on every recent run — 78 MB, 78 MB, 139 MB. Three hundred and eight seconds of runner time and eighty megabytes per push, for a red result that nothing is allowed to act on and nobody reads. Looking only at the job's conclusion said "success", because `continue-on-error` was doing its job; the artifact is what told the truth.

Its rule 2 described the pre-push hook as one filter among several. It is not. The `main` ruleset carries `deletion` and `non_fast_forward` and no required status checks, so GitHub reports and never refuses. The hook is the only thing that can stop a bad commit, which makes its completeness and its speed properties of the gate rather than conveniences ([ADR 0017](0017-build-artifacts-disk-and-reuse.md), [ADR 0018](0018-the-tests-run-optimised.md)).

Both corrections point the same way: run on every push exactly what can refuse a change, run everything else on a rhythm that suits it, and let the run say what it cost ([ADR 0020](0020-the-gate-reports-its-own-cost.md)).

## Decision

1. Maintainers push directly to `main`; no other branches are kept. An outside contribution arrives as a pull request from a fork, passes the same gate, and a maintainer lands it on `main`.
2. Before every push the pre-push hook runs `Scripts/verify.sh`. It is the only thing that can refuse a commit, so it MUST cover every check that does not need a device: strict SwiftLint, `shellcheck` and `actionlint` ([ADR 0019](0019-the-process-is-code-too.md)), a warning-free package build, all package tests and the coverage gate.
3. On every push CI MUST run, and the aggregate `Gate` check MUST require: the shell and workflow linters; the package tests with the coverage gate; the iOS release build with pointer authentication, verified with `lipo`; the full DSP accuracy matrix; the Mac release build and disk image checked as notarization and App Review would ([ADR 0013](0013-release-readiness.md), [ADR 0014](0014-disk-image-distribution.md)); the Mac Debug build with the app's own unit tests; and the UI tests with the accessibility audit on iPhone and on iPad.
4. A check that cannot fail the gate MUST NOT run on every push. It runs on a rhythm of its own, where going red is the notification that it is still broken and going green is the notification that it is not. The Mac screens run weekly for exactly this reason, and return to rule 3 the day they can pass.
5. Line coverage MUST be 100 % for `TunerCore`, `TunerAudio` and `TunerFeature`, excluding only `Sources/TunerAudio/Hardware/`.
6. A change to behavior covered by an ADR MUST update or supersede that ADR in the same commit; a change to documented numbers MUST update the documents in the same commit.
7. The `main` ruleset forbids deletion and force-pushes, with no bypass actors.
8. Every script in `Scripts/` MUST answer `--help` and `-h` with its own header — what it does and how to run it — and exit 0 before it validates an argument or changes anything. The scripts are not installed on the PATH, so this is their manual page; `Scripts/lib/help.sh` is the one implementation, sourced by all of them.

## Consequences

- A red gate blocks nothing on GitHub by itself; the discipline is the hook, and not pushing on red.
- Rule 4 costs a delay: a Mac screen that breaks for a reason of ours is found within a week instead of within a push. That is the correct trade while the same job fails for a reason that is not ours, and it is wrong the moment they can pass, which is why rule 4 names the way back.
- Judging a job by its conclusion is not enough when a step may fail without failing the job. The artifact a failure uploads is the evidence, and it is what rule 4 was decided on.
- Each push drops about 308 seconds of runner time and about 78 megabytes of stored artifacts.

## Enforcement

- `.githooks/pre-push` and `Scripts/verify.sh` run rule 2 before every push.
- `.github/workflows/ci.yml` runs rule 3 and its `gate` job requires every one of those jobs.
- `.github/workflows/mac-screens.yml` runs the Mac screens weekly and on demand, under rule 4.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` checks the shape of the gate, that every job it waits for is baselined, and that no job carries a timeout out of proportion to what it costs.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ScriptPolicyTests.swift` checks rule 8, and that the hook's script runs the linters of rule 2.
