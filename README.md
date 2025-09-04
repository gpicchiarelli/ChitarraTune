# ChitarraTune

<!-- Badges -->
<p>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml"><img alt="Build" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml"><img alt="SwiftLint" src="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/gpicchiarelli/ChitarraTune?include_prereleases&label=release"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/gpicchiarelli/ChitarraTune/total?label=downloads"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/gpicchiarelli/ChitarraTune?color=blue"></a>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-1f6feb?logo=apple">
  <a href="https://github.com/gpicchiarelli/ChitarraTune/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/gpicchiarelli/ChitarraTune?style=social"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/issues"><img alt="Open issues" src="https://img.shields.io/github/issues/gpicchiarelli/ChitarraTune"></a>
  <img alt="Last commit" src="https://img.shields.io/github/last-commit/gpicchiarelli/ChitarraTune">
  <a href="https://github.com/gpicchiarelli/ChitarraTune/pulls"><img alt="Open PRs" src="https://img.shields.io/github/issues-pr/gpicchiarelli/ChitarraTune"></a>
  <img alt="Repo size" src="https://img.shields.io/github/repo-size/gpicchiarelli/ChitarraTune">
  <img alt="Contributors" src="https://img.shields.io/github/contributors/gpicchiarelli/ChitarraTune">
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

## Segnalazione bug
- Apri un’issue su GitHub usando i template: https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose
- Pagina di supporto (IT/EN): https://gpicchiarelli.github.io/ChitarraTune/bug.html

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
 - Versione: il target aggiorna `CFBundleShortVersionString` (tag git) e `CFBundleVersion` (SHA breve) in fase di build; About mostra anche “Versione: tag (commit)” e include un bottone “Copia versione”.
 - Licenza in‑app: la finestra “Licenza (BSD‑3)” legge `LICENSE` dal bundle (UTF‑8) ed evita caratteri strani.

## Sito Web (GitHub Pages)
- Cartella `docs/`: sito statico mostrato su GitHub Pages (impostazione “Pages → Build from /docs”).
- URL: https://gpicchiarelli.github.io/ChitarraTune/
- Branding: `doc/branding.md`

## Localizzazione
- UI: chiavi in `Apps/Shared/Localization/*/Localizable.strings`
- Permesso microfono: `Apps/macOS/*/InfoPlist.strings`
- Lingue incluse: Italiano (`it`), Inglese (`en`)

Per aggiungere una lingua, crea una nuova cartella `xx.lproj` in entrambe le posizioni e traduci le chiavi.

## Test
- Core (SwiftPM): `swift test --parallel --enable-code-coverage`
- Web (docs): test basilari sulla presenza di elementi chiave e link GitHub
- CI: esegue automaticamente i test SwiftPM e genera un report di coverage (upload come artifact)
- Copertura: sommario in Actions → job CI (GITHUB_STEP_SUMMARY)

## Sicurezza
Il target macOS è sandboxed e abilita l’ingresso audio tramite entitlements (`Apps/macOS/ChitarraTune.entitlements`). Alla prima esecuzione verrà richiesta l’autorizzazione al microfono.

## Privacy
L’app usa esclusivamente il microfono per calcolare la frequenza in locale. Nessun dato viene trasmesso né raccolto.

## Licenza
BSD 3‑Clause — vedi `LICENSE`. La licenza è inoltre visibile dal menù Help dell’app e sul sito.

## Marchi
Apple, macOS, Xcode e i relativi loghi sono marchi di Apple Inc., registrati negli Stati Uniti e in altri Paesi e regioni.

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
- Workflow build: `.github/workflows/ci.yml` (runner macOS-14, `setup-xcode@v1` con Xcode 15.x).
- Workflow release: `.github/workflows/release.yml` (crea zip della .app su `git tag v*`).
