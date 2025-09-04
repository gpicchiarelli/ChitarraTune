# Localizzazione

File chiave
- `Apps/Shared/Localization/it.lproj/Localizable.strings`
- `Apps/Shared/Localization/en.lproj/Localizable.strings`
- `Apps/macOS/*/InfoPlist.strings` (messaggi permesso microfono)

Lingue supportate
- Italiano (`it`), Inglese (`en`)
- Dichiarate in `Apps/macOS/Info.plist` come `CFBundleLocalizations` (selezione automatica in base alla lingua di sistema).

Chiavi principali
- Interfaccia: titolo app, modalità Auto/Manuale, selezione corda, A4 Hz, input device, avvisi “segnale debole” e “accordata”.
- Accordature: `tuning.standard`, `tuning.dropD`, `tuning.dadgad`, `tuning.openG`, `tuning.openD`, `tuning.halfDown`.

Aggiungere una lingua
1. Crea `xx.lproj/Localizable.strings` in `Apps/Shared/Localization/`
2. Crea `xx.lproj/InfoPlist.strings` in `Apps/macOS/`
3. Aggiungi `xx` a `CFBundleLocalizations` se necessario

