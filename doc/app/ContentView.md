# ContentView (App)

Posizione: `Apps/Shared/ContentView.swift`

## Stato/Persistenza
- `@StateObject audio = AudioEngineManager()` — modello di dati
- `@State isAuto: Bool` — modalità Auto/Manuale (sincronizzato con `audio.mode`)
- `@State manualIndex: Int` — indice corda selezionata (Manuale)
- `@AppStorage("A4") storedA4: Double` — calibrazione A4
- `@AppStorage("isAutoMode") storedIsAuto: Bool` — persistenza modalità
- `@AppStorage("manualStringIndex") storedManualStringIndex: Int` — persistenza corda manuale
- `@AppStorage("tuningPresetID") storedPresetID: String` — persistenza preset
- `@AppStorage("preferredInputUID") storedPreferredInputUID: String` — persistenza input device
- `@State selectedInputUID: String` — selezione input per Picker

## Layout
- Header titolo, indicatore “Accordata!” quando stabile (±5c per N cicli)
- Indicatore a barra `TuningBarView` (solo barra; ago rimosso)
- Letture numeriche: Hz e cents
- Avviso segnale debole `signal.weak`
- Toolbar (sempre visibile su macOS):
  - Bottone start/stop monitoraggio (`monitoringButton`)
  - Picker modalità Auto/Manuale (`modePicker`, `.segmented`)
  - Picker corda manuale (`stringPicker`, `.segmented`, visibile solo in Manuale)
- Sezioni `GroupBox` (macOS‑style):
  - `controls.mode`: Auto/Manuale + Picker corda (dinamico dal preset)
  - `controls.tuningPreset`: selezione accordatura (menu + label localizzata)
  - `controls.calibration`: slider A4 (415–466), stepper fine (0.1Hz), Reset
  - `controls.audio`: selezione dispositivo e nome attuale

## Comportamento
- `onAppear`: ripristino preferenze, refresh dispositivi, applicazione selezione input
- `onChange`: sincronizza `audio.mode`, aggiorna preferenze, applica device

## Accessibilità e UI Test
- Identificatori accessibilità usati dai test: `appTitleLabel`, `modePicker`, `stringPicker`, `monitoringButton`.
- I test UI impostano `UITEST_DISABLE_AUDIO=1` per evitare il prompt del microfono; la toolbar a livello superiore garantisce che i controlli principali restino individuabili anche senza input audio disponibile.

## TuningBarView
- Indicatore orizzontale con tacche a −50/−25/0/+25/+50
- Zona verde centrale ±5c; colore indicatore: verde (<5), giallo (<15), rosso (altrimenti)
