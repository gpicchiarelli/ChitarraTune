# Architettura – ChitarraTune

Documento che descrive il flusso dati e i ruoli dei componenti principali.

---

## Panoramica

ChitarraTune è un’app multipiattaforma (macOS, iOS, iPadOS) per l’accordatura della chitarra. Il codice è organizzato in:

- **ChitarraTuneCore**: logica DSP, preset di accordatura, costanti (senza dipendenze da UI o AVFoundation).
- **Apps/Shared**: UI, gestione audio, Intents, localizzazione, errori.
- **Apps/macOS** e **Apps/ios**: entry point e asset specifici per piattaforma.

---

## Flusso dati (tuning)

1. **Input**: L’utente avvia l’ascolto (pulsante Start o Siri/Shortcuts). `AudioEngineManager.start()` richiede il permesso microfono, configura `AVCaptureSession` con il dispositivo audio scelto e avvia la cattura.
2. **Cattura**: `AVCaptureAudioDataOutput` invia buffer PCM al delegate su una coda dedicata. I campioni vengono accodati nel `SessionAudioBuffer` dell’istanza di `AudioEngineManager`.
3. **Elaborazione**: Un task periodico (`startAudioProcessing`) preleva campioni dal buffer della sessione, applica una finestra di analisi (`TunerConfig.analysisWindowSize`), gate sul RMS (`TunerConfig.noiseGateRMS`) e chiama `estimatePresetTuning` (che usa `PitchDetector` YIN e `nearestString` / `frequency(for:referenceA:)` da Core).
4. **Output**: Il risultato (`TuningEstimate`: frequenza, cents, etichetta corda, chiarezza) viene pubblicato su `AudioEngineManager.latestEstimate`. La UI (`ContentView`, `UniversalTuningBar`) osserva queste proprietà e aggiorna indicatore, nota e stato “in tune”.
5. **Stabilità**: La logica “in tune” richiede un numero consecutivo di letture entro la soglia (`TunerConfig.inTuneThresholdCents`, `stableReadingsRequired`).

---

## Ruolo dei moduli

| Modulo | Ruolo |
|--------|--------|
| **ChitarraTuneCore** | `PitchDetector` (YIN), `GuitarNotes` (corde standard), `TuningPresets` (preset + `frequency(for:referenceA:)`, `nearestString`), `TunerConfig` (costanti DSP/soglie). Nessuna dipendenza da AVFoundation o SwiftUI. |
| **Apps/Shared** | `AudioEngineManager`: sessione AV, buffer, smoothing, noise gate, pubblicazione stima. `ContentView` / `PreferencesView` / `UniversalTuningBar`: UI. `ChitarraTuneIntents`: Start/Stop/SetMicrophone/SetMode/SetPreset/Calibrate. `NoteLabelLocalization`: note in italiano (Do/Re/Mi). `TuningError`: errori tipizzati e messaggi localizzati. |
| **SessionAudioBuffer** | Actor per sessione: ogni `AudioEngineManager` ha il proprio buffer; i campioni AVCapture vengono accodati lì e consumati dal relativo manager. |
| **SessionStore / TunerSession** | Gestione multi-sessione: più tab/finestre, ognuna con un proprio `AudioEngineManager` (input e preset indipendenti). Siri/Shortcuts agiscono sulla sessione attiva. |

---

## Dipendenze

- **UI → AudioEngineManager**: La vista principale e le preferenze usano `@EnvironmentObject AudioEngineManager` (o equivalente) per start/stop, preset, stima, errore.
- **Intents → AudioEngineManager**: Gli App Intents usano `AudioEngineManager.sharedForIntents` (impostato all’avvio dell’app) per avviare/fermare l’accordatura e cambiare preset/microfono/modalità.
- **AudioEngineManager → Core**: Usa `PitchDetector`, `estimatePresetTuning`, `TunerConfig`; non dipende da SwiftUI (salvo `@MainActor` e `@Published`).

---

## Configurazione e costanti

- **TunerConfig** (in Core): finestra di analisi, range di frequenza, soglie “in tune”, smoothing, noise gate, letture stabili. Unico punto per modificare i parametri DSP.
- **TuningError**: errori tipizzati (microfono negato, nessun dispositivo, cattura fallita) con messaggi localizzati in `Localizable.strings`.

---

## Testing

- **ChitarraTuneTests** (unit test): testano `PitchDetector`, `frequency(for:referenceA:)`, `nearestString`, `scaledFrequency` / `nearestGuitarString`, `localizedNoteLabelItalian`, `TunerConfig`. Il target dipende dall’app macOS e usa `@testable import ChitarraTune` con TEST_HOST/BUNDLE_LOADER.
- **ChitarraTuneUITests**: UI test su macOS (avvio, presenza elementi).

Per maggiori dettagli su gap e miglioramenti si veda [SOFTWARE_ENGINEERING_ASSESSMENT.md](SOFTWARE_ENGINEERING_ASSESSMENT.md).
