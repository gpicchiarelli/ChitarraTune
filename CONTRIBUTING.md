# Contributing to ChitarraTune

Thanks for helping. Issues and pull requests are welcome in English or Italian.

## Ground rules

These are invariants of the product. Each is a binding [architecture decision record](docs/adr/README.md) that a test enforces: a change that breaks one is not merged, and changing one means superseding its ADR.

1. **Audio never leaves memory** ([ADR 0002](docs/adr/0002-audio-never-leaves-memory.md)). No recording, no files, no export, no network, in any build, Debug included.
2. **Least privilege** ([ADR 0003](docs/adr/0003-least-privilege-and-platform-security.md)). No new entitlement, permission or Info.plist capability without a discussion first.
3. **No third-party dependencies.** There are none today; open an issue before proposing one.
4. **Swift 6 with complete strict concurrency** ([ADR 0007](docs/adr/0007-concurrency-model.md)). `@unchecked Sendable` is forbidden; `nonisolated(unsafe)` and `MainActor.assumeIsolated` only at the audited sites listed in `ArchitecturePolicyTests`; wait for events, never poll.
5. **A measurement never changes by accident** ([ADR 0008](docs/adr/0008-measurement-integrity.md)). See [Measurement changes](#measurement-changes).
6. **English and Italian.** User-facing text lives in the string catalogs (`App/Resources/*.xcstrings`), never in code, and exists in both languages.

## Getting set up

You need Xcode 26 or later. Clone and build as the [README](README.md#build-from-source) shows, and put your own signing team in `Config/Local.xcconfig`, which git ignores:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Then enable the pre-push hook once:

```bash
git config core.hooksPath .githooks
```

## Where things live

| Path | What it is |
| :-- | :-- |
| `Packages/ChitarraTuneKit/Sources/TunerCore` | Pure logic: pitch math, tunings, the detector, the string filters, the tuning engine. No I/O. |
| `Packages/ChitarraTuneKit/Sources/TunerAudio` | Microphone capture, permission, input discovery. `Hardware/` holds the only code that needs real hardware. |
| `Packages/ChitarraTuneKit/Sources/TunerFeature` | Observable presentation models, settings, the window hub. |
| `App/` | The SwiftUI app: screens, commands, App Intents, resources. |
| `Shared/`, `Controls/` | The intent shared with the Controls extension, and the extension itself. |
| `Config/` | Build settings, entitlements, Info.plists. |
| `Scripts/` | The gate, release checks, the disk image, screenshots, versioning. |
| `docs/` | Architecture, decisions, accuracy, accessibility, signing, release readiness ([index](docs/README.md)). |

Put behavior in `TunerCore` or `TunerFeature`, where synthetic signals and test doubles can exercise it, and keep `App/` thin.

## The quality gate

`Scripts/verify.sh` runs what the pre-push hook runs: SwiftLint in strict mode, a warning-free package build, every test, and the coverage floors in `Scripts/coverage-thresholds.json`. `--app` also builds the app; `--release` also builds the Mac app exactly as a release and checks it as notarization and App Review would. CI repeats all of it on GitHub (**Gate**, **Lint**, **CodeQL**), adds the app builds, the UI tests on iPhone, iPad and Mac, and the optimized DSP matrix; a red run is fixed before anything else.

| Guard | What it stops |
| :-- | :-- |
| No compiler warnings | Concurrency and API problems creeping in |
| SwiftLint `--strict` | Style drift and risky constructs |
| 100 % line coverage | Untested code. The one exclusion is `TunerAudio/Hardware/`, a handful of thin system calls |
| Hostile-input and fuzz tests | Crashes on `NaN`, absurd sample rates, garbage audio |
| Policy tests (`RepositoryPolicyTests`) | A network API, an entitlement, an unpinned action, a missing translation, a document that no longer matches the code, a broken ADR |
| Release checks ([ADR 0013](docs/adr/0013-release-readiness.md)) | A Mac build that notarization or App Review would reject |
| CodeQL | Known classes of security bugs |

**Every bug fix ships with a test that fails without the fix.** That is how a mistake stays fixed.

### Measurement changes

ChitarraTune is a measuring instrument, so what it reads is protected separately ([ACCURACY.md](docs/ACCURACY.md)):

- `GoldenReadingsTests` compares every frame the engine produces for 132 reference signals with `Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/golden-readings.txt`. A refactor must reproduce them: discrete values (string, gate, in-tune, held) exactly, continuous ones within 0.02 cent, because the last digits of a float differ between CPUs.
- A change that is *meant* to alter a measurement regenerates the file with `UPDATE_GOLDEN=1 swift test --package-path Packages/ChitarraTuneKit --filter GoldenReadings`, compares the old and new readings field by field, and explains in its commit why the new numbers are more correct, with the accuracy statistics before and after. Never regenerate just to make a test pass.
- An accuracy envelope that no regeneration can loosen holds at both analysis rates: the right string on every note, a median error of at most 2 cents per note and 0.5 cent overall.
- Recordings of a real guitar, with the reading of a reference tuner, make the best tests: see [the recording corpus](Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md).

## Sending a change

Maintainers push to `main` through the gate. Everyone else opens a pull request from a fork; it passes the same gate before it is merged ([ADR 0009](docs/adr/0009-quality-gate-and-change-process.md)).

- Run `Scripts/verify.sh` first.
- Add or update tests for what you changed. `TunerCore` tests use generated signals, so no microphone is needed.
- If you touched audio, the engine or permissions, try it with a real instrument and say how in the pull request.
- One concern per change: it is easier to review and to revert.
- Commit messages: a short summary, and a body explaining *why* when it is not obvious. Italian or English.
- A change that contradicts an ADR supersedes it in the same commit.

## Bugs and security problems

Bugs and ideas go through the [issue forms](https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose). Security problems are reported **privately**: see [SECURITY.md](SECURITY.md).

## License

By contributing you agree that your work is released under the project's [BSD 3-Clause License](LICENSE), and you may add yourself to [CONTRIBUTORS.md](CONTRIBUTORS.md).
