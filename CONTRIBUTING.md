# Contributing to ChitarraTune

Thanks for helping. English and Italian are both welcome in issues and pull requests.

## Ground rules

These are invariants of the product, recorded as binding [architecture decision records](docs/adr/README.md) and enforced by tests. A change that breaks one will not be merged; changing one means superseding its ADR.

1. **Audio never leaves memory** ([ADR 0002](docs/adr/0002-audio-never-leaves-memory.md)). No recording, no files, no export, no networking, in any build, Debug included.
2. **Least privilege.** No new entitlement, permission or Info.plist capability without a discussion first.
3. **No third-party dependencies.** The project has none today. Open an issue before proposing one.
4. **Swift 6, strict concurrency** ([ADR 0007](docs/adr/0007-concurrency-model.md)). The build uses `SWIFT_STRICT_CONCURRENCY = complete`. `@unchecked Sendable` is forbidden; `nonisolated(unsafe)` and `MainActor.assumeIsolated` only at the audited sites listed in `ArchitecturePolicyTests`.
5. **English and Italian.** User-facing text lives in the string catalogs (`App/Resources/*.xcstrings`), never in code.

## Getting set up

You need Xcode 26 or later. See the [README](README.md#getting-started) for the build steps, and put your own signing team in `Config/Local.xcconfig` (never commit it):

```
DEVELOPMENT_TEAM = YOURTEAMID
```

## Where things live

| Path | What it is |
| --- | --- |
| `Packages/ChitarraTuneKit/Sources/TunerCore` | Pure logic: pitch maths, tunings, YIN detector, tuning engine. No I/O. |
| `Packages/ChitarraTuneKit/Sources/TunerAudio` | Microphone capture, permission, input discovery. |
| `Packages/ChitarraTuneKit/Sources/TunerFeature` | Observable presentation models and settings. |
| `App/` | The SwiftUI app: screens, App Intents, resources. |
| `Config/` | Build settings, entitlements, Info.plist. |

Put behaviour in `TunerCore` or `TunerFeature` where it can be tested with synthetic signals and test doubles. Keep `App/` thin.

## The quality gate

You push straight to `main`. What stands between a commit and `main` is `Scripts/verify.sh`, which the pre-push hook runs on every push (enable it once with `git config core.hooksPath .githooks`); a push that fails it never leaves your machine. CI then runs the same checks (**Gate**, **Lint**, **CodeQL**) on GitHub, and a red run is fixed before anything else. Run the checks by hand with:

```bash
Scripts/verify.sh
```

It runs SwiftLint in strict mode, builds the package with warnings as errors, runs every test and enforces the coverage thresholds in `Scripts/coverage-thresholds.json`. Add `--app` to build the app too, or `--release` to build the Mac app exactly as a release and check it as notarization and App Review would (`Scripts/release-check.sh`, also run by CI on every push).

What the gate protects, and how:

| Guard | What it stops |
| --- | --- |
| Zero compiler warnings (`-warnings-as-errors`) | Concurrency and API problems creeping in |
| SwiftLint `--strict` | Style drift and risky constructs |
| 100 % line coverage of every module | Untested code. The only exclusion is the hardware boundary, `Packages/ChitarraTuneKit/Sources/TunerAudio/Hardware/` (see its README) |
| Hostile-input and fuzz tests | Crashes on `NaN`, absurd sample rates, garbage audio |
| Policy tests (`RepositoryPolicyTests`) | A network API, a new entitlement, an unpinned action, a missing translation, or a README that no longer matches the code |
| CodeQL | Known classes of security bugs |
| Release readiness (`Scripts/release-check.sh`, [ADR 0013](docs/adr/0013-release-readiness.md)) | A Mac build that notarization or App Review would reject: a debugging entitlement, an extra entitlement, a missing architecture, a non-system library, a missing purpose string or privacy manifest |

**Every bug fix ships with a test that fails without the fix.** That is how a mistake stays fixed.

### Measurement changes

ChitarraTune is a measuring instrument, so what it reads is protected on its own:

- `GoldenReadingsTests` compares every frame the engine produces for 132 reference signals with `Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/golden-readings.txt`. A refactor must reproduce them: discrete values (string, gate, in-tune, held) exactly, continuous ones to within 0.02 cent, because the last digits of a float differ between CPUs.
- If a change is *meant* to alter a measurement, regenerate the file with `UPDATE_GOLDEN=1 swift test --package-path Packages/ChitarraTuneKit --filter GoldenReadings`, compare the old and new readings field by field, and explain in the commit why the new numbers are more correct. Never regenerate just to make the test pass.
- The same test enforces an accuracy envelope that no regeneration can loosen: right string on every note, median error ≤ 2 cents per note and ≤ 0.5 cent overall.
- Recordings of a real guitar, with a reading from a reference tuner, are the missing piece: see `Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md`.

## Before you open a pull request

```bash
Scripts/verify.sh
```

- Add or update tests for what you changed. `TunerCore` tests use generated signals, so no microphone is needed.
- If you touched audio, DSP or permissions, try it with a real microphone and say so in the pull request.
- Keep pull requests focused. One concern per pull request is easier to review and to revert.
- Commit messages: a short imperative summary, plus a body explaining *why* when it is not obvious. Italian or English.

## Reporting bugs and security issues

Use the issue forms for bugs and feature requests. Report **security problems privately**; see [SECURITY.md](SECURITY.md).

## License

By contributing you agree that your work is released under the project's [BSD 3-Clause License](LICENSE).
