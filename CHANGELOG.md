# Changelog

All notable changes to the project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added

- **TunerConfig** (`ChitarraTuneCore/TunerConfig.swift`): costanti centralizzate per DSP e soglie (finestra di analisi, range frequenze, in-tune, smoothing, noise gate).
- **TuningError** (`Apps/Shared/TuningError.swift`): enum di errori tipizzati (microfono negato/limitato, nessun dispositivo, cattura fallita) con messaggi localizzati (en/it).
- **Logging**: `Logger` in `AudioEngineManager` (avvio/arresto cattura, errori) e negli App Intents (Start/Stop tuner).
- **Unit tests** (target ChitarraTuneTests): test per PitchDetector, TuningPresets (`frequency`, `nearestString`), GuitarNotes (`scaledFrequency`, `nearestGuitarString`), NoteLabelLocalization (`localizedNoteLabelItalian`), TunerConfig.
- **Documentation**: `docs/ARCHITECTURE.md` (flusso dati e ruoli moduli), `.swiftlint.yml`, `CHANGELOG.md`.

### Changed

- **AudioEngineManager**: costanti DSP/soglie sostituite con `TunerConfig.*`; gestione errori in `start()` tramite `TuningError` e `localizedMessage`.
- **Localizable.strings**: nuove chiavi per messaggi di errore (`error.microphone.denied`, `error.microphone.restricted`, `error.no.audio.device`, `error.capture.failed`).
- **CI**: unit test eseguiti in pipeline; SwiftLint reso bloccante (rimosso `continue-on-error`).

---

## [1.0.0] and earlier

- Release iniziale: accordatore chitarra per macOS e iOS, preset multipli, calibrazione A4, Siri/Shortcuts, localizzazione it/en, note italiane Do/Re/Mi.
