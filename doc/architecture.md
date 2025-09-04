# Architettura

Obiettivo: accordatore per chitarra (macOS) con rilevamento in tempo reale e UI semplice.

- `ChitarraTuneCore` (Swift Package locale):
  - `PitchDetector`: stima della fondamentale via YIN (CMNDF) con interpolazione parabolica.
  - `TuningPresets`: preset accordature (Standard, Drop D, DADGAD, Open G/D, mezzo tono sotto) + mapping MIDI→Hz.
  - `GuitarNotes`: tipi base e utilità (compatibilità legacy, funzioni helper).

- App (SwiftUI + AVAudioEngine):
  - `AudioEngineManager`: cattura audio, buffering, gating, smoothing adattivo e stima pitch → `TuningEstimate`.
  - `ContentView`: interfaccia (barra di intonazione, modalità Auto/Manuale, selezione accordatura, calibrazione A4, selezione input).
  - `ChitarraTuneApp`: entrypoint SwiftUI (scene principale).

Flusso dati (semplificato)
1) AVAudioEngine input → buffer float
2) `AudioEngineManager.append(...)`: gating RMS, finestra 2048, chiamata YIN
3) `PitchDetector.estimateFrequency(...)` → Hz + clarity
4) `estimatePresetTuning(...)`: mapping all’accordatura, calcolo cents (correzione ottava in Manuale)
5) Smoothing adattivo sui cents + stabilità
6) UI aggiorna barra e indicatori

Prestazioni e latenza
- Finestra analisi 2048 e tap da 1024 frame per aggiornamenti più frequenti
- YIN riduce errori di ottava su pizzichi forti
- Smoothing adattivo alla clarity per stabilità vs reattività

