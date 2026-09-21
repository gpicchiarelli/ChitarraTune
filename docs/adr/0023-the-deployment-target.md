# ADR 0023: The deployment target

Status: Accepted (2026-09-21)

## Context

`Config/Base.xcconfig` sets `MACOSX_DEPLOYMENT_TARGET = 27.0` and `IPHONEOS_DEPLOYMENT_TARGET = 27.0`. A free guitar tuner is the kind of app somebody installs on the phone they already have, so requiring the operating system that came out this autumn costs most of the audience it could have had. That is a real price, it is being paid on purpose, and until now it was paid without being written down anywhere — which made it look like a habit rather than a decision.

The price is not only the audience. GitHub's GA runner image is `macos-26`, where an app with a macOS 27 minimum cannot launch at all, and the only image carrying macOS 27 is the `xcode-27` **preview**, whose virtual GPU has no shader slice for SwiftUI's renderer (`unable to find air64_v27 slice`, RenderBox), so the window never draws. The Mac UI tests therefore cannot run on any push ([B6](../RELEASE_READINESS.md#b6-the-mac-screens-are-not-tested-on-any-push)), and the whole gate runs on a preview image that can change or be withdrawn without notice.

What is bought with it is a code base with no availability fences and no compatibility paths: `@Observable` and its fine-grained observation, `Synchronization.Atomic` and `Mutex`, `isolated deinit`, `IntentModes.foreground`, `onScrollGeometryChange`, `containerBackground(_:for:)`, the `.icon` app icon, Enhanced Security with `hardened-process` and `dyld-ro`, and typed `throws`. Every one of those appears in the sources without a single `if #available`. Supporting the previous system version would not add a flag; it would add a second version of the presentation layer, a second concurrency story, and a second security posture to keep true — in an app whose defining property is that every rule it states is enforced by a test.

## Decision

1. The deployment target is the current major version of each system, and it is stated in exactly one place: `Config/Base.xcconfig`. Every other file that names it — the package manifest, the release check, the README, the platform table, the changelog — is held against that one.
2. The code MUST NOT carry availability fences or compatibility paths for older systems. `if #available` inside this app's own sources means the target is wrong, not that the check is clever.
3. This choice MUST be restated, not merely inherited, at each yearly bump: raising the target is the same edit as this record, and the reason above has to still be true.
4. The consequences of rule 1 that fall on the gate MUST be visible where they bite, not only here. A check that the runner image cannot run does not run on every push and says why in the workflow that keeps it ([ADR 0021](0021-the-gate-and-the-change-process.md) rule 4).
5. Lowering the target is a decision of the same weight as raising it, and supersedes this record rather than amending it. It is the one change that would give the Mac screens a gate again, and the audience with them.

## Consequences

- The reachable installed base is, on the day this is written, close to zero, and grows with the system's own adoption. For a tuner, that is the main cost and it is accepted.
- The Mac UI tests and their accessibility audits run weekly in `.github/workflows/mac-screens.yml` instead of on every push. The Mac Debug build and the app's own unit tests still block the gate, so macOS compilation is never unverified.
- The whole gate depends on a preview runner image. `.github/workflows/ci.yml` says so once, at the top, and names the move to `macos-27` as the thing to do the day it exists.
- No source file needs an availability check, which is what makes the concurrency, observation and security stories single-valued.
- This record is the one to read before arguing about the audience. It does not claim the trade is obviously right; it claims it was made, and by whom, and what it costs.

## Enforcement

- `Config/Base.xcconfig` is the single source of the minimum, and `Scripts/release-check.sh` reads it rather than repeating it.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/DocumentationSpecTests.swift` holds `Packages/ChitarraTuneKit/Package.swift`, `README.md`, `docs/PLATFORMS.md`, `CHANGELOG.md` and `CONTRIBUTING.md` to that one number, and fails on last year's.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` refuses an availability check in the app's own sources (rule 2).
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` keeps `.github/workflows/mac-screens.yml` off the push path and pins every runner image.
