# ADR 0016: Build artifacts and disk

Status: Accepted (2026-09-20)

## Context

Nothing this project builds belongs in the repository: iCloud adds extended attributes to anything under `~/Documents` and code signing then fails, so every script already builds elsewhere ([ADR 0009](0009-quality-gate-and-change-process.md)). "Elsewhere" was never defined, so each script, and each person or agent running `xcodebuild` by hand, invented a path of its own. On 20 September 2026 the caches held 7.3 GB: eight derived-data trees from ad-hoc commands, and 1.3 GB of intermediates from a screenshot run whose 33 MB of PNGs had long since been produced. Nothing was wrong with any single run; nothing ever removed what a run left behind.

## Decision

1. Build output MUST be written under `$HOME/Library/Caches/ChitarraTune/`, never inside the working tree. A script MUST let the caller move that root, and use the caller's value when it is set.
2. A run that succeeds MUST leave behind nothing but its artifact: the PNGs, the disk image, the printed verdict. Every build tree a script creates, its own package build included, MUST be gone when it returns 0. A run that fails MUST keep its tree, which is when it is worth reading, and every script MUST take `KEEP_BUILD=1` for the times a successful run has to be examined too. The cost is rebuilding from cold next time, and that cost is accepted: a machine whose disk fills up cannot build at all.
3. A build run by hand, by a person or an agent, MUST use the same root, under a name that says what it is: `$HOME/Library/Caches/ChitarraTune/dd-<purpose>`.
4. Nothing under that root may be anything but rebuildable output: no source, no git worktree, no signing material, no only copy of anything.
5. `Scripts/clean-caches.sh` is the one way to empty it. It MUST refuse to run while a build is in flight, MUST leave pinned tool downloads alone unless asked, and MUST never delete a git worktree.
6. Artifacts that are the product rather than the scaffolding — the App Store screenshots, the disk image — stay out of git as well ([ADR 0014](0014-disk-image-distribution.md)). They are regenerated for each release, so a stale copy is not kept for its own sake.

## Consequences

- A tidy machine costs a rebuild now and then: what is deleted is time, never work.
- One root means one command to see what the project is holding, and one to free it.
- Rule 3 binds whoever drives the build, which a test cannot check on its own; the reviewer checks it when a script or a workflow adds a path.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ScriptPolicyTests.swift` checks that every script writing build output puts it under the cache root, that the root is overridable, and that `Scripts/clean-caches.sh` exists and answers `--dry-run` without deleting anything.
- `Scripts/clean-caches.sh` itself refuses a root that is not this project's cache, and skips git worktrees.
