# App Icon (macOS)

Questa app usa un Asset Catalog `Apps/Shared/Assets.xcassets` con un set `AppIcon` già predisposto (`Contents.json`).

Percorso:
- `Apps/Shared/Assets.xcassets/AppIcon.appiconset/`

Sono richieste le seguenti dimensioni (macOS):
- 16×16, 32×32, 128×128, 256×256, 512×512 — ciascuna @1x e @2x

Filenames attesi (già referenziati nel `Contents.json`):
- `AppIcon-16.png`, `AppIcon-16@2x.png`
- `AppIcon-32.png`, `AppIcon-32@2x.png`
- `AppIcon-128.png`, `AppIcon-128@2x.png`
- `AppIcon-256.png`, `AppIcon-256@2x.png`
- `AppIcon-512.png`, `AppIcon-512@2x.png`

Come generare (da un PNG sorgente quadrato ad alta risoluzione, es. 1024×1024):
- Con `sips` (preinstallato su macOS):
  - `sips -Z 16    icon.png --out AppIcon-16.png`
  - `sips -Z 32    icon.png --out AppIcon-16@2x.png`
  - `sips -Z 32    icon.png --out AppIcon-32.png`
  - `sips -Z 64    icon.png --out AppIcon-32@2x.png`
  - `sips -Z 128   icon.png --out AppIcon-128.png`
  - `sips -Z 256   icon.png --out AppIcon-128@2x.png`
  - `sips -Z 256   icon.png --out AppIcon-256.png`
  - `sips -Z 512   icon.png --out AppIcon-256@2x.png`
  - `sips -Z 512   icon.png --out AppIcon-512.png`
  - `sips -Z 1024  icon.png --out AppIcon-512@2x.png`

Dopo aver copiato i file nella cartella `AppIcon.appiconset`, Xcode compilerà automaticamente l’icona. Il progetto è già configurato con `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

Nota: Inserisci l’immagine fornita come sorgente (`icon.png`) e genera i vari tagli con i comandi sopra.
