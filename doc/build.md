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

