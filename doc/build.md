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
