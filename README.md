# ChitarraTune

Accordatore per chitarra (E2–E4) scritto in Swift/SwiftUI per macOS. Core DSP in puro Swift con autocorrelazione; interfaccia semplice con ago e indicazione dei cents. Localizzato in Italiano e Inglese. Modalità Auto/Manuale e calibrazione A4.

- Solo chitarra: corde E2, A2, D3, G3, B3, E4
- Algoritmo: autocorrelazione con interpolazione parabolica
- SwiftUI + AVAudioEngine (macOS)
- Modalità: Auto (riconoscimento corda) o Manuale (selezione corda)
- Calibrazione A4: 415–466 Hz
- Smoothing e stabilità: indicatore “Accordata!” entro ±5 cents (stabile)
- Licenza: BSD 3-clause (Picchiarelli Giacomo)

## Requisiti
- Xcode 15 o successivo
- macOS 12+

## Struttura repo
- `Package.swift`: libreria `ChitarraTuneCore`
- `Sources/ChitarraTuneCore`: pitch detection + mappatura corde
- `Apps/Shared`: UI SwiftUI (App, ContentView, AudioEngineManager)
- `Apps/Shared/Localization`: Localizable.strings IT/EN
- `Apps/macOS`: Info.plist + InfoPlist.strings IT/EN
- `Apps/macOS/ChitarraTune.entitlements`: sandbox + microfono
- `ChitarraTune.xcodeproj`: progetto Xcode macOS

## Costruzione
### Con Xcode (consigliato)
1. Apri `ChitarraTune.xcodeproj` con Xcode 15+
2. Seleziona lo schema `ChitarraTune`
3. Esegui su macOS

Nota: il core DSP è in `ChitarraTuneCore` (Swift Package locale, vedi `Package.swift`).

## Sito Web (GitHub Pages)
- Cartella `chitarratune.github.io`: sito statico elegante, pronto per GitHub Pages.
- Istruzioni dettagliate: `chitarratune.github.io/README.md`.

## Localizzazione
- UI: chiavi in `Apps/Shared/Localization/*/Localizable.strings`
- Permesso microfono: `Apps/macOS/*/InfoPlist.strings`
- Lingue incluse: Italiano (`it`), Inglese (`en`)

Per aggiungere una lingua, crea una nuova cartella `xx.lproj` in entrambe le posizioni e traduci le chiavi.

## Sicurezza
Il target macOS è sandboxed e abilita l’ingresso audio tramite entitlements (`Apps/macOS/ChitarraTune.entitlements`). Alla prima esecuzione verrà richiesta l’autorizzazione al microfono.

## Privacy
L’app usa esclusivamente il microfono per calcolare la frequenza in locale. Nessun dato viene trasmesso né raccolto.

## Licenza
BSD 3‑clause — vedi `LICENSE`.

## Documentazione
- Documentazione estesa (classi/funzioni): vedi cartella `doc/`.
  - Panoramica: `doc/README.md`
  - Architettura: `doc/architecture.md`
  - Costruzione: `doc/build.md`
  - Localizzazione: `doc/localization.md`
  - Core DSP: `doc/core/*`
  - App: `doc/app/*`
