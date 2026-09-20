# ADR 0020: The gate reports its own cost

Status: Accepted (2026-09-20)

## Context

On 20 September 2026 a change to this repository turned on parallel UI testing in CI. It made the gate slower and then broke it: `UI · iPhone` went from 854 s to 936 s and `UI · iPad` from 1218 s to 1564 s and failed, because XCUITest distributes work by test class and all eighteen UI tests live in one, so the second worker was a cloned simulator booted for nothing — and on iPad that clone never came up (`unable to connect to "com.apple.instruments.deviceservice.lockdown"`).

Nothing about the change was subtle. What was missing was that nobody could see it. The durations existed only in the GitHub API, one run at a time; the run summary said "Gate: failure" and nothing about cost. It took reading job timings by hand, three pushes later, to find out. In the same exercise the question "did `App · iOS Release` regress from 64 s to 158 s?" could only be answered by pulling eleven historical runs and looking at the spread — 57 s to 158 s, with a 135 s outlier from long before the change. It had not regressed. Both of those answers should have been a glance at the run.

A repository that holds its Swift to 100 % line coverage, strict linting and a suite of tests that read the repository itself was measuring nothing about the process that runs them, while the longest job in that process is about twenty minutes and flaky.

The same blindness applies one level down. `UI · iPad` costs about 68 seconds per test, where a simulator launch is five to ten. Where the rest goes is not known, and cannot be guessed responsibly — guessing is what caused this record to exist. The result bundle knows, and was being thrown away on every green run.

## Decision

1. Every CI run MUST report what it cost: the `gate` job prints each job's duration beside the expected value in `.github/ci-baseline.json`, to the run summary, and warns on anything above `tolerance` times its baseline or with no baseline at all.
2. That report MUST warn and MUST NOT fail. These runners are too variable for a timing to be a verdict: the same unchanged job has been measured at 57 s and at 158 s. A number that fails a build teaches people to pad it; a number that is simply visible does not.
3. Every job MUST have an entry in `.github/ci-baseline.json`. A change to what a job does MUST update its number in the same commit, and the commit message MUST say what was measured ([ADR 0018](0018-the-tests-run-optimised.md) rule 4).
4. Every job that runs tests MUST report what each test cost, from the result bundle, on the run itself — passing or failing. `Scripts/test-timings.sh` does this, and it is the same command a person runs on a bundle from their own machine.
5. An optimisation to the gate MUST be justified by a measurement taken before it, not by a mechanism assumed to hold. Parallel UI testing was turned on without checking that XCUITest parallelises by class; the check cost nothing and would have answered it.

## Consequences

- A change that makes the gate slower says so on the run that makes it, to whoever made it, while they are still looking.
- Baselines are numbers in a file, so they drift and need touching when a job legitimately changes. Rule 3 makes that a required part of the change rather than a chore discovered later.
- Rule 2 means the report is advisory. That is deliberate and it is the whole design: its value is visibility, not enforcement, and pretending otherwise would make it a source of red runs that people learn to ignore.
- Rule 5 is a rule a machine cannot check. The reviewer checks it when a change touches the shape of a job, and the commit message is where the evidence goes.
- The `gate` job now needs `actions: read` to read the run's own job durations, and a checkout to read the baseline. That is one additional read permission on the cheapest job in the file.

## Enforcement

- `.github/workflows/ci.yml` prints the per-job table in `gate` and the per-test table in every job that runs tests.
- `.github/ci-baseline.json` holds the expected durations and the tolerance.
- `Scripts/test-timings.sh` turns a result bundle into that per-test table, on CI and by hand.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` checks that the baseline is well-formed, that the gate reads it, that the report cannot fail a run, and that every job running tests reports what each test cost.
