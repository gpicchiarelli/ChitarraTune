# ADR 0019: The process is code too

Status: Accepted (2026-09-20)

## Context

Swift in this repository is held to SwiftLint in strict mode, `-warnings-as-errors`, CodeQL, 100 % line coverage and a suite of tests that read the repository itself. The shell was held to nothing.

That shell is not incidental. About 1 900 lines of it across `Scripts/` and `.github/workflows/` decide what the gate checks, what the release signs, what the disk image contains and what is published to the App Store. It was the only code here that nothing read but a person. `.github/workflows/ci.yml` even carried two `# shellcheck disable=SC2086` directives — written for a linter that this project never ran.

The cost of that gap is known, not hypothetical. `continue-on-error: ${{ matrix.allowFailure == true }}` never evaluated true, so the one CI job documented as unable to stop the gate had been stopping it; actionlint reports that comparison as a type mismatch. On the first run of these two tools over the repository they also found, in the step that imports the Developer ID certificate, `security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')` — an unquoted command substitution whose word splitting is deliberate but which loses a keychain whose path contains a space, in the workflow that signs and notarizes what people install.

At `--severity=warning` with `-x`, the whole of `Scripts/` produced five findings, all in `Scripts/make-dmg.sh`: a loop counter that was never read, a `flags` array in one function and a `flags` string in another, and the shipped image's "nothing unexpected is on this volume" check parsing `ls` output. None was catastrophic. All five were worth knowing, and none of them was going to be found by reading.

`--severity=style` adds about forty more, almost all `SC2015` on the `[ test ] && pass "…" || fail "…"` idiom that `Scripts/release-check.sh` is built from. That idiom is safe here because `pass` always returns 0, and rewriting forty lines of a working script to satisfy a note is not a good trade.

## Decision

1. Every shell script and every workflow MUST pass `shellcheck -x --severity=warning` and `actionlint` before it is pushed. Both run in `Scripts/verify.sh` and in the `lint` job of `.github/workflows/ci.yml`, and that job is part of the `Gate`.
2. The floor is `warning`, not `style`. Raising it is a decision for another record, made with the cleanup it implies, not a flag flipped in passing.
3. A `# shellcheck disable=` directive MUST name a linter that actually runs, and MUST carry a comment saying why the rule does not apply. A directive for a linter nobody runs is a comment pretending to be a control.
4. Both linters MUST be pinned to an exact version and refused unless their SHA-256 matches. A linter runs with the full permissions of the job, so it is supply chain like every action this project pins to a commit ([ADR 0010](0010-supply-chain-and-repository-security.md)).
5. A runner label that actionlint does not know MUST be declared in `.github/actionlint.yaml`, never silenced with an ignore pattern. Today that is `xcode-27`, and the declaration disappears with the label when a generally available `macos-27` image exists.
6. The pinned linters are not required to be installed on a contributor's machine: `Scripts/verify.sh` says so and continues. CI runs both on every push regardless, so the gate never depends on what somebody has locally.

## Consequences

- The shell that builds and signs the product is now read by something that does not get tired.
- Two more downloads in the cache, which `Scripts/clean-caches.sh` already leaves alone unless asked.
- One more job on the `Gate`, on Linux, which is the cheapest runner there is.
- Rule 2 means `shellcheck` will keep printing style notes that nothing enforces. That is honest: they are visible to anyone who raises the severity by hand, and they are not a gate.

## Enforcement

- `.github/workflows/ci.yml` runs both linters in its `lint` job, which the `gate` job requires.
- `Scripts/verify.sh` runs both before every push, and names them when they are missing.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` checks that the `lint` job exists and is in the gate's `needs`, that both linters are checksum-verified, and that every `# shellcheck disable=` directive in a workflow names a rule and carries a reason.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ScriptPolicyTests.swift` checks that `Scripts/verify.sh` runs both linters at the agreed severity.
- `.github/actionlint.yaml` declares the runner label actionlint does not know.
