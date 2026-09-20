# ADR 0017: Build artifacts, disk and reuse

Status: Accepted (2026-09-20)

## Context

[ADR 0016](0016-build-artifacts-and-disk.md) put every build under one root outside the working tree and required a successful run to leave nothing behind. The first half was right and is kept here unchanged. The second half was measured a day later and costs more than it saves.

Changes go straight to `main`; the repository ruleset requires no status check, so nothing on GitHub can refuse a commit. The pre-push hook — `Scripts/verify.sh` — is the only thing that can, which makes it the gate in practice and its speed a correctness property: a gate slow enough to be worth skipping is a gate that gets skipped. Under ADR 0016 rule 2 it deleted the package build every time it passed, so every push paid for a cold build of the kit and its tests. CI on the same commit costs about sixty-six minutes of macOS runner time and twenty-three minutes of waiting, so the local run is where a mistake has to be caught, not on GitHub.

The 7.3 GB that motivated ADR 0016 were eight derived-data trees from ad-hoc commands and 1.3 GB of screenshot intermediates: trees nobody named, nobody reused and nothing removed. The package build is the opposite — one tree, one name, read again by the very next command. Deleting it did not address what filled the disk; it only made the loop cold.

Rules 2 and 5 of ADR 0016 also contradicted each other. Rule 5 called `Scripts/clean-caches.sh` "the one way to empty" the cache; rule 2 emptied it on every green run, so the cleaner could only ever find what a *failed* run had left. Its own header already described the behaviour this record makes true — "verify.sh says when the cache has grown enough to want it" — which `Scripts/verify.sh` did not do.

Finally, ADR 0016 rule 3 bound whoever drives a build to name its scratch path, and said "a test cannot check it on its own". A test can. While this record was being written, `Packages/ChitarraTuneKit/.build` held 211 MB inside `~/Documents`, iCloud-synced, invisible to the cleaner, put there by `.github/workflows/ci.yml` itself: two steps ran `swift build` and `swift test` with no `--scratch-path`, which is exactly the command a person or an agent copies out of a workflow.

## Decision

1. Build output MUST be written under `$HOME/Library/Caches/ChitarraTune/`, never inside the working tree. A script MUST let the caller move that root, and MUST use the caller's value when it is set.
2. Exactly one build tree is long-lived: the package build, `kit-build`, which the next command reuses. A run that succeeds MUST leave it in place.
3. Every other build tree a script creates is one-shot: the release check's gigabyte, the screenshot intermediates, the disk-image staging. A run that succeeds MUST remove it; a run that fails MUST keep it, which is when reading it is worth something; and every script that makes one MUST take `KEEP_BUILD=1`.
4. The long-lived tree is bounded, not unbounded. `Scripts/verify.sh` MUST report what the cache holds and say when it is worth clearing, and `Scripts/clean-caches.sh` MUST remain the one command that clears it.
5. Every build MUST name where it builds. A script, a workflow step or a command run by hand MUST pass `--scratch-path` or `-derivedDataPath` under the root of rule 1, by hand under a name that says what it is (`dd-<purpose>`). A build tree inside the working tree MUST fail the gate.
6. Nothing under that root may be anything but rebuildable output: no source, no git worktree, no signing material, no only copy of anything.
7. `Scripts/clean-caches.sh` MUST refuse to run while a build is in flight, MUST leave pinned tool downloads alone unless asked, and MUST never delete a git worktree.
8. Artifacts that are the product rather than the scaffolding — the App Store screenshots, the disk image — stay out of git as well ([ADR 0014](0014-disk-image-distribution.md)). They are regenerated for each release, so a stale copy is not kept for its own sake.

## Consequences

- The pre-push gate is incremental instead of cold, so running it is cheaper than reasoning about whether to skip it.
- A few hundred megabytes live in `~/Library/Caches`, which is where a cache belongs: not synced by iCloud, purgeable by the system under pressure, and emptied by one command.
- Keeping a build tree between runs means a stale intermediate can outlive the source that made it. `Scripts/coverage-gate.sh` therefore takes the newest coverage profile rather than the first one it finds, and a build that behaves impossibly is answered with `Scripts/clean-caches.sh --now` before anything else.
- Rule 5 no longer rests on a reviewer noticing. It is a test, and it fails on the state the repository was actually in.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ScriptPolicyTests.swift` checks that build output goes under the cache root, that the root is overridable, that a script making a one-shot tree removes it and offers `KEEP_BUILD=1`, that the package build is the only tree exempt, and that no build tree exists inside the working tree.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` checks that no workflow step runs `swift build` or `swift test` without naming a scratch path.
- `Scripts/clean-caches.sh` refuses a root that is not this project's cache, refuses to run while a build is in flight, and skips git worktrees.
- `Scripts/verify.sh` reports the size of the cache and names the command that empties it.
