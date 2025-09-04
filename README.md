# ChitarraTune

<!-- Badges -->
<p>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml"><img alt="Build" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gpicchiarelli/ChitarraTune?include_prereleases&label=release"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/gpicchiarelli/ChitarraTune/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gpicchiarelli/ChitarraTune?color=blue"></a>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple">
</p>

Accordatore per chitarra per macOS, scritto in Swift/SwiftUI. DSP in puro Swift con algoritmo YIN (CMNDF), indicatori in tempo reale, modalità Auto/Manuale, accordature alternative e calibrazione A4. Localizzato in Italiano e Inglese.

Caratteristiche principali
- Pitch detection: YIN con raffinamento parabolico, finestra 2048, aggiornamenti frequenti (tap 1024), smoothing adattivo.
- Accordature: Standard, Drop D, DADGAD, Open G, Open D, Mezzo tono sotto (Half‑step down).
- Modalità: Auto (riconoscimento corda) o Manuale (selezione corda del preset).
- Visualizzazione: barra orizzontale con zona centrale ±5 cents e colori (verde/giallo/rosso).
- Calibrazione A4: 415–466 Hz.
- Dispositivi input: selezione microfoni/interfacce (es. iRig) con persistenza e refresh.
- Localizzazione: Italiano e Inglese.
- Sicurezza e privacy: sandbox, richiesta microfono, elaborazione interamente locale.
- Licenza: BSD 3‑Clause.

Sito: https://gpicchiarelli.github.io/ChitarraTune/

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

Note
- Il core DSP è in `ChitarraTuneCore` (Swift Package locale, vedi `Package.swift`).
- Le App Icons si generano con `scripts/generate_appicons.sh` partendo da un PNG sorgente (vedi `doc/appicon.md`).

## Sito Web (GitHub Pages)
- Cartella `docs/`: sito statico mostrato su GitHub Pages (impostazione “Pages → Build from /docs”).
- URL: https://gpicchiarelli.github.io/ChitarraTune/
- Branding: `doc/branding.md`

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
BSD 3‑Clause — vedi `LICENSE`. La licenza è inoltre visibile dal menù Help dell’app e sul sito.

## Documentazione
- Documentazione estesa (classi/funzioni): vedi cartella `doc/`.
  - Panoramica: `doc/README.md`
  - Architettura: `doc/architecture.md`
  - Costruzione: `doc/build.md`
  - Localizzazione: `doc/localization.md`
  - Core DSP: `doc/core/*`
  - App: `doc/app/*`
  - Branding: `doc/branding.md`

## Badge e CI
- Il workflow di build è in `.github/workflows/ci.yml` (macOS runner, Xcode 15).
