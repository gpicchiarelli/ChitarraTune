# Documentation

Everything written about ChitarraTune is here or linked from here. What people who use the app read is in **English and Italian**, both halves of the same file: the user guide, [SUPPORT.md](../SUPPORT.md), [PRIVACY.md](../PRIVACY.md) and the README. What contributors and maintainers read is in **English only**, so there is one text to keep true to the code.

## For people who use ChitarraTune

| | |
| :-- | :-- |
| [User Guide](guide/en/index.md) · [Manuale utente](guide/it/index.md) | How to use ChitarraTune, task by task; on the Mac also in Help ▸ ChitarraTune Help |
| [Support](../SUPPORT.md) | Help, common questions, how to send a diagnostic report |
| [Privacy](../PRIVACY.md) | What the app does with your data: nothing leaves your device |
| [Accuracy](ACCURACY.md) | How precise the tuner is, how that is measured, and its limits |
| [Accessibility](ACCESSIBILITY.md) | VoiceOver, Dynamic Type, contrast, keyboard, and what is still to check |
| [Changelog](../CHANGELOG.md) | What changed in each version |

## For contributors

| | |
| :-- | :-- |
| [Contributing](../CONTRIBUTING.md) | Ground rules, setup, the quality gate, measurement changes |
| [Architecture](ARCHITECTURE.md) | Modules, signal path, concurrency, state |
| [Decisions](adr/README.md) | Architecture decision records: what is settled, why, and what checks it |
| [Platforms](PLATFORMS.md) | Requirements and per-platform behavior |
| [Security policy](../SECURITY.md) | Security model and how to report a vulnerability |
| [Code of conduct](../CODE_OF_CONDUCT.md) | What is expected of everyone taking part |
| [Hardware boundary](../Packages/ChitarraTuneKit/Sources/TunerAudio/Hardware/README.md) | The only code that needs real hardware, and why it sits outside the coverage gate |
| [Recording corpus](../Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md) | How a recording of a real guitar becomes a regression test |
| [Contributors](../CONTRIBUTORS.md) | Who has worked on ChitarraTune |

## For maintainers

| | |
| :-- | :-- |
| [Release readiness](RELEASE_READINESS.md) | What still stands between `main` and a public release |
| [Code signing](CODE_SIGNING.md) | Entitlements, signing, notarization, the disk image, secrets |
| [Apple compliance](APPLE_COMPLIANCE.md) | App Store Review Guidelines and platform requirements |
| [App Store submission](../AppStore/README.md) | Listing, submission and unlisted distribution |
| [Device test plan](DEVICE_TEST_PLAN.md) | What to check on real hardware before each release |
