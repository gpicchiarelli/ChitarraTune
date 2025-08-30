# ChitarraTune

Accordatore per chitarra (E2–E4) scritto in Swift/SwiftUI per macOS. Core DSP in puro Swift con autocorrelazione; interfaccia semplice con ago e indicazione dei cents. Localizzato in Italiano e Inglese.

- Solo chitarra: corde E2, A2, D3, G3, B3, E4
- Algoritmo: autocorrelazione con interpolazione parabolica
- SwiftUI + AVAudioEngine (macOS)
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
- `project.yml`: definizione XcodeGen (target macOS)

## Costruzione
### Opzione A) XcodeGen (consigliata)
1. Installa XcodeGen: `brew install xcodegen`
2. Genera il progetto: `xcodegen`
3. Apri `ChitarraTune.xcodeproj` e seleziona lo schema `ChitarraTune`
4. Esegui su Mac

### Opzione B) Manuale da Xcode
1. Crea un nuovo progetto macOS > App (SwiftUI)
2. Aggiungi come Swift Package locale la cartella del repo (prod. `ChitarraTuneCore`)
3. Aggiungi al target i file in `Apps/Shared` (App, ContentView, AudioEngineManager) e `Apps/Shared/Localization`
4. Imposta `Info.plist` e aggiungi `InfoPlist.strings` localizzati (vedi `Apps/macOS/*`)

## Localizzazione
- UI: chiavi in `Apps/Shared/Localization/*/Localizable.strings`
- Permesso microfono: `Apps/macOS/*/InfoPlist.strings`
- Lingue incluse: Italiano (`it`), Inglese (`en`)

Per aggiungere una lingua, crea una nuova cartella `xx.lproj` in entrambe le posizioni e traduci le chiavi.

## Privacy
L’app usa esclusivamente il microfono per calcolare la frequenza in locale. Nessun dato viene trasmesso né raccolto.

## Licenza
BSD 3‑clause — vedi `LICENSE`.
