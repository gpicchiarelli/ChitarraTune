# Build

Requisiti
- Xcode 15+
- macOS 12+

Passi
1. Apri `ChitarraTune.xcodeproj`
2. Seleziona lo schema `ChitarraTune`
3. Esegui su macOS

Note
- Il core DSP è in `ChitarraTuneCore` (directory `Sources/ChitarraTuneCore`), incluso direttamente nel target app.
- Le impostazioni di sandbox e microfono sono in `Apps/macOS/ChitarraTune.entitlements` e `Info.plist`.
- Le lingue supportate (IT/EN) sono dichiarate in `Info.plist` (`CFBundleLocalizations`).
 - Versioning: il target imposta automaticamente `CFBundleShortVersionString` e `CFBundleVersion` dai dati Git (ultimo tag e SHA breve) tramite uno script di build. Per ottenere il valore corretto, esegui la build in una working copy git con almeno un tag.
 - About/Help: il pannello “Informazioni” mostra anche “Versione: tag (commit)” e un pulsante “Copia versione”. La finestra “Licenza” legge il file `LICENSE` dal bundle.

## Test rapidi
- Core: `swift test --parallel --enable-code-coverage`
- UI (XCUITest) con audio disabilitato: `xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune -destination platform=macOS CODE_SIGNING_ALLOWED=NO test` con `UITEST_DISABLE_AUDIO=1` nel `launchEnvironment` (già impostato nei test).

## Packaging (locale)
- Esegui `scripts/package_app.sh vX.Y.Z` per ottenere `ChitarraTune-<version>-macOS.zip` e relativo `.sha256`. Lo script lancia i test e fallisce se non passano.
 - Se presente un’identità “Apple Development” nel Portachiavi, lo script prova a firmare localmente (altrimenti ad‑hoc). La build NON è notarizzata.

## Firma e notarizzazione (CI)
Per ottenere un pacchetto firmato e notarizzato tramite GitHub Actions:
- Crea un certificato "Developer ID Application" e esportalo in `.p12`.
- Crea una chiave API in App Store Connect (Issuer ID, Key ID e file `.p8`).
- Aggiungi i seguenti Secret nel repo:
  - `MACOS_CERT_P12`: contenuto base64 del `.p12` (es. `base64 -i cert.p12 | pbcopy`)
  - `MACOS_CERT_PASSWORD`: password del `.p12`
  - `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, `NOTARY_API_KEY_P8` (contenuto base64 del `.p8`)
  - facoltativi: `CODESIGN_IDENTITY` (es. `Developer ID Application: Nome Cognome (TEAMID)`), `MACOS_TEAM_ID`
- Avvia una Release (tag `vX.Y.Z` o "Run workflow" da Actions con input versione). Il workflow:
  1) Compila Release
  2) Firma con Hardened Runtime
  3) Invia a notarizzazione (`notarytool`) e attende
  4) Esegue stapling
  5) Crea lo zip e checksum
