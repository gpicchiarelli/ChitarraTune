# ChitarraTune

Accordatore per chitarra (E2–E4) scritto in Swift/SwiftUI, multipiattaforma per iOS, iPadOS, macOS e tvOS. Core DSP in puro Swift con autocorrelazione; interfaccia semplice con ago e indicazione dei cents.

- Solo chitarra: corde E2, A2, D3, G3, B3, E4
- Algoritmo: autocorrelazione con interpolazione parabolica
- SwiftUI + AVAudioEngine
- Licenza: BSD 3-clause (Picchiarelli Giacomo)

## Requisiti
- Xcode 15 o successivo
- iOS/iPadOS 15+, macOS 12+, tvOS 15+

## Struttura repo
- `Package.swift`: libreria `ChitarraTuneCore`
- `Sources/ChitarraTuneCore`: pitch detection + mappatura corde
- `Apps/Shared`: UI SwiftUI condivisa (App, ContentView, AudioEngineManager)
- `Apps/iOS|macOS|tvOS/Info.plist`: Info per ciascuna piattaforma
- `project.yml`: definizione XcodeGen (target iOS, macOS, tvOS)

## Costruzione
### Opzione A) XcodeGen (consigliata)
1. Installa XcodeGen: `brew install xcodegen`
2. Genera il progetto: `xcodegen`
3. Apri `ChitarraTune.xcodeproj` e seleziona il target desiderato (iOS/macOS/tvOS)
4. Esegui su dispositivo/simulatore (su tvOS verrà mostrato un messaggio: input microfono non disponibile)

### Opzione B) Manuale da Xcode
1. Crea un nuovo progetto Multi‑platform > App (SwiftUI)
2. Aggiungi come Swift Package locale la cartella del repo (prod. `ChitarraTuneCore`)
3. Aggiungi al target i file in `Apps/Shared` (App, ContentView, AudioEngineManager)
4. Imposta `Info.plist` con `NSMicrophoneUsageDescription` (usa quelli in `Apps/<piattaforma>/Info.plist`)

## tvOS
Apple TV non espone il microfono alle app di terze parti: il target tvOS mostra una schermata informativa. L’accordatore funziona su iPhone/iPad/Mac.

## Privacy
L’app usa esclusivamente il microfono per calcolare la frequenza in locale. Nessun dato viene trasmesso né raccolto.

## Licenza
BSD 3‑clause — vedi `LICENSE`.

