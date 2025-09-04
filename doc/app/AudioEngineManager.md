# AudioEngineManager (App)

Posizione: `Apps/Shared/AudioEngineManager.swift`

## Scopo
Gateway tra AVAudioEngine e il core DSP, applica gating/smoothing, gestisce i dispositivi input e l’esposizione dei dati alla UI.

## Proprietà pubbliche (Published)
- `latestEstimate: TuningEstimate?` — ultima stima (Hz, cents, etichetta)
- `isRunning: Bool` — stato engine
- `inputAvailable: Bool` — disponibilità input/microfono
- `isInTune: Bool` — stato stabilità (cent < 5 per N cicli)
- `referenceA: Double` — calibrazione A4 (415–466)
- `availableInputDevices: [AudioInputDevice]` — dispositivi input CoreAudio
- `selectedInputUID: String?` — UID selezionata (o nil = default di sistema)
- `isSignalWeak: Bool` — RMS sotto soglia (spia UI)
- `currentInputName: String` — descrizione del dispositivo in uso
- `mode: Mode` — `.auto` o `.manual(Int)` (indice corda nel preset)
- `preset: TuningPreset` — accordatura corrente
- `availablePresets: [TuningPreset]` — elenco preset disponibili

## Parametri privati
- `analysisWindow = 2048` — ampiezza finestra DSP
- `smoothingBase=0.25`, `smoothingMax=0.7` — smoothing adattivo (in codice calcolato da `clarity`)
- `stableThreshold = 6` — cicli consecutivi entro ±5c per considerare “accordata”
- `noiseGateRMS = 0.004` — gate di rumore su RMS della finestra

## Metodi
- `start()`
  - Controlla permessi microfono, installa tap su input node (`bufferSize=1024`), avvia engine.
- `stop()`
  - Rimuove tap se presente, ferma engine, aggiorna stato.
- `append(samples:sampleRate:)`
  - Buffer scorrevole di 2 finestre, gating via RMS, stima pitch con `estimatePresetTuning(...)`.
  - Outlier rejection (clarity < 0.2 o |cents| > 300)
  - Smoothing adattivo: alpha in funzione di `clarity`. Reset se salto > 80c.
  - Aggiorna `latestEstimate` e `isInTune` (stabile entro ±5c per `stableThreshold`).

### Dispositivi Input (CoreAudio)
- `refreshInputDevices()` — enumerazione dispositivi con stream input; popolazione elenco e nome corrente.
- `setPreferredInputDevice(uid:)` — selezione esplicita (riavvio engine, set `kAudioOutputUnitProperty_CurrentDevice`).
- `setSystemDefaultInputDevice()` — ritorna al default di sistema.
- Helpers privati:
  - `setCurrentDeviceID(_:)`, `defaultInputDeviceID()`
  - `getCFStringProperty(_:_: )` — lettura sicura proprietà CoreAudio (CFString)
  - `deviceName(for:)` — wrapper per nome dispositivo

## Note Prestazioni
- Aggiornamenti frequenti (tap 1024 frame) e finestra 2048 ⇒ UI reattiva.
- Possibili ulteriori miglioramenti: ring buffer (no copie), vDSP, filtri HPF/notch.

