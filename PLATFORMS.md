# Piattaforme supportate · Supported Platforms

ChitarraTune è un’app **multipiattaforma** (macOS, iPhone, iPad) con codice condiviso e target nativi separati.

ChitarraTune is a **multi‑platform** app (macOS, iPhone, iPad) with shared code and separate native targets.

## Riepilogo · Summary

| Piattaforma | Target Xcode | Deployment | Device family |
|-------------|--------------|------------|----------------|
| **macOS**   | ChitarraTune (macOS) | 12.0+ | Mac |
| **iPhone**  | ChitarraTune iOS     | 16.0+ | iPhone (1) |
| **iPad**    | ChitarraTune iOS     | 16.0+ | iPad (2) |

- **TARGETED_DEVICE_FAMILY** per il target iOS: `1,2` (iPhone + iPad).
- Stesso bundle ID per iOS e iPadOS: `com.chitarratune.app` (configurabile in Xcode).
- Codice condiviso: `Apps/Shared/`, `ChitarraTuneCore/`, `ChitarraTune.xcassets/`.
- Configurazione per target: `Apps/macOS/` (Info.plist, entitlements), `Apps/ios/` (Info.plist, entitlements).

## Build

- **macOS**: scheme **ChitarraTune** → destinazione macOS.
- **iPhone / iPad**: scheme **ChitarraTune iOS** → destinazione iPhone o iPad (simulatore o dispositivo).

## Comportamento per piattaforma

- **macOS**: finestra principale + pannello Preferenze (NSPanel), menu, shortcut ⌘,.
- **iPhone**: layout compatto, sheet impostazioni con detent .medium/.large, orientamenti Portrait + Landscape.
- **iPad**: layout regolare (max width 560 pt), sheet impostazioni in stile form, supporto Split View / Slide Over (UIRequiresFullScreen = false), orientamenti tutti e quattro, supporto input indiretto (tastiera/trackpad).

## Info.plist

- **macOS**: `Apps/macOS/Info.plist` — LSMinimumSystemVersion 12.0, categoria Musica, descrizione microfono.
- **iOS/iPadOS**: `Apps/ios/Info.plist` — UISupportedInterfaceOrientations (iPhone + ~ipad), UIRequiresFullScreen false, UIApplicationSupportsIndirectInputEvents true, NSMicrophoneUsageDescription, capacità microfono.

## Localizzazione

- Lingue: Italiano (it), English (en).  
- Stringhe: `Apps/Shared/Localization/{en,it}.lproj/Localizable.strings`.  
- Info.plist macOS: `Apps/macOS/{en,it}.lproj/InfoPlist.strings` (nome app, ecc.).

## Icone

- **AppIcon** (ChitarraTune.xcassets): slot per iPhone, iPad, iOS Marketing (1024), e Mac; tutte le dimensioni richieste sono presenti.
