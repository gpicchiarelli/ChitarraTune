# PitchDetector (ChitarraTuneCore)

Posizione: `Sources/ChitarraTuneCore/PitchDetector.swift`

## Tipi
- `struct PitchResult`:
  - `frequency: Double`: frequenza stimata [Hz]
  - `clarity: Double`: affidabilità [0–1], maggiore è meglio

## Proprietà
- `sampleRate: Double`: frequenza di campionamento
- `minFrequency: Double = 70.0`: limite inferiore ricerca [Hz]
- `maxFrequency: Double = 600.0`: limite superiore ricerca [Hz]

## Init
- `init(sampleRate: Double)`

## Metodi
- `estimateFrequency(samples: [Float]) -> PitchResult?`
  - Implementa YIN (CMNDF):
    1) Preprocess (rimozione DC, finestra di Hann)
    2) Difference function `d(τ)` per `τ ∈ [minLag, maxLag]`
    3) CMNDF (cumulative mean normalized difference)
    4) Soglia assoluta (0.12) + ricerca del minimo locale
    5) Interpolazione parabolica intorno al minimo
    6) Clarity = `1 - CMNDF_min` (clamp 0–1)
  - Restituisce `nil` se finestra insufficiente, clarity bassa o frequenza non valida

- `estimatePresetTuning(samples:sampleRate:referenceA:preset:forcedIndex:) -> TuningEstimate?`
  - Usa `estimateFrequency` per la fondamentale, quindi mappa alla corda più vicina del preset dato.
  - Se `forcedIndex` è presente (modalità Manuale), normalizza la frequenza vicino al target correggendo eventuali errori d’ottava (moltiplicando/dividendo per 2 finché il rapporto rientra ~[0.55, 1.9]). Calcola quindi i cents vs la corda selezionata.

- `estimateGuitarTuning(...) -> TuningEstimate?`
  - Helper per compatibilità: usa il preset Standard e mappa dall’enum legacy `GuitarString`.

## Considerazioni prestazionali
- Complessità: O(N·T) con T numero di lag valutati; con finestra 2048 e range 70–600 Hz è adatto al real‑time.
- Per ottimizzare ulteriormente:
  - Limitare `maxLag` nei dintorni della corda selezionata in Manuale
  - vDSP/Accelerate per differenze vettoriali
  - Ring buffer per evitare copie della finestra

