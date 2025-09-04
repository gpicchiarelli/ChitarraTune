# TuningPresets (ChitarraTuneCore)

Posizione: `Sources/ChitarraTuneCore/TuningPresets.swift`

## Tipi
- `struct NoteSpec { midi: Int, label: String }`
  - MIDI number della nota (A4=69), etichetta visuale (es. "E2").

- `struct TuningPreset: Identifiable`
  - `id: String` — identificativo (es. "standard")
  - `nameKey: String` — chiave localizzata (es. `tuning.standard`)
  - `strings: [NoteSpec]` — da bassa ad alta

## Funzioni
- `frequency(for midi:Int, referenceA:Double) -> Double`
  - Conversione MIDI→Hz: `Hz = A4 * 2^((midi-69)/12)`

- `nearestString(in:preset:for:referenceA:) -> (index:Int, label:String, cents:Double)`
  - Trova la corda del preset più vicina a una frequenza e calcola i cents.

## Preset forniti
- Standard (E2 A2 D3 G3 B3 E4)
- Drop D (D2 A2 D3 G3 B3 E4)
- DADGAD (D2 A2 D3 G3 A3 D4)
- Open G (D2 G2 D3 G3 B3 D4)
- Open D (D2 A2 D3 F#3 A3 D4)
- Half-step down (Eb2 Ab2 Db3 Gb3 Bb3 Eb4)

