# Contributing to ChitarraTune

Thanks for helping. English and Italian are both welcome in issues and pull requests.

## Ground rules

These are invariants of the product. A change that breaks one will not be merged.

1. **Audio stays on the device.** No networking, no recording, no persistence of samples.
2. **Least privilege.** No new entitlement, permission or Info.plist capability without a discussion first.
3. **No third-party dependencies.** The project has none today. Open an issue before proposing one.
4. **Swift 6, strict concurrency.** The build uses `SWIFT_STRICT_CONCURRENCY = complete`. Do not silence the compiler with `@unchecked Sendable` or `nonisolated(unsafe)` unless the invariant is documented at the use site.
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

It runs SwiftLint in strict mode, builds the package with warnings as errors, runs every test and enforces the coverage thresholds in `Scripts/coverage-thresholds.json`. Add `--app` to build the app too.

What the gate protects, and how:

| Guard | What it stops |
| --- | --- |
| Zero compiler warnings (`-warnings-as-errors`) | Concurrency and API problems creeping in |
| SwiftLint `--strict` | Style drift and risky constructs |
| 100 % line coverage of every module | Untested code. The only exclusion is the hardware boundary, `Packages/ChitarraTuneKit/Sources/TunerAudio/Hardware/` (see its README) |
| Hostile-input and fuzz tests | Crashes on `NaN`, absurd sample rates, garbage audio |
| Policy tests (`RepositoryPolicyTests`) | A network API, a new entitlement, an unpinned action, a missing translation, or a README that no longer matches the code |
| CodeQL | Known classes of security bugs |

**Every bug fix ships with a test that fails without the fix.** That is how a mistake stays fixed.

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
