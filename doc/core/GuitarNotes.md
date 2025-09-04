# GuitarNotes (ChitarraTuneCore)

Posizione: `Sources/ChitarraTuneCore/GuitarNotes.swift`

## Tipi
- `enum GuitarString: CaseIterable, Sendable`
  - Valori: `.e2, .a2, .d3, .g3, .b3, .e4`
  - `name: String` → etichetta leggibile (E2..E4)
  - `baseFrequency: Double` → frequenza con A4=440 Hz

- `struct TuningEstimate: Sendable`
  - `frequency: Double` — frequenza stimata (Hz)
  - `clarity: Double` — affidabilità 0–1
  - `stringLabel: String` — etichetta corda (es. "E2")
  - `cents: Double` — scostamento dalla corda selezionata o più vicina
  - `stringIndex: Int?` — indice corda nel preset (se disponibile)

## Funzioni
- `scaledFrequency(for:referenceA:) -> Double`
  - Scala le frequenze base in funzione della calibrazione A4.

- `nearestGuitarString(for:referenceA:) -> (string: GuitarString, cents: Double)`
  - Trova nell’accordatura standard la corda più vicina a una frequenza data e i relativi cents.

Note
- L’app oggi usa le accordature generalizzate (preset) definite in `TuningPresets.swift`. Le API legacy restano per compatibilità.

