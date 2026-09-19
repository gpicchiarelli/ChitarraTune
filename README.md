<div align="center">

<img src="docs/assets/icon.png" width="128" height="128" alt="ChitarraTune app icon">

# ChitarraTune

**A precise, private guitar tuner for Mac, iPhone and iPad.**<br>
<sub>Accordatore per chitarra preciso e privato per Mac, iPhone e iPad.</sub>

<br>

[Features](#features) &nbsp;·&nbsp; [Tunings](#tunings) &nbsp;·&nbsp; [How it works](#how-it-works) &nbsp;·&nbsp; [Siri & Shortcuts](#siri--shortcuts) &nbsp;·&nbsp; [Install](#install) &nbsp;·&nbsp; [Getting started](#getting-started) &nbsp;·&nbsp; [Privacy & security](#privacy--security) &nbsp;·&nbsp; [Italiano](#italiano)

<br>

<!-- app-store-badges:en:start -->
<!-- Official App Store badges: Scripts/app-store-badges.sh <App Store ID> adds them once the app is live. -->
<!-- app-store-badges:en:end -->

<p>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/gpicchiarelli/ChitarraTune/ci.yml?branch=main&style=flat-square&logo=github&label=CI"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://img.shields.io/github/actions/workflow/status/gpicchiarelli/ChitarraTune/codeql.yml?branch=main&style=flat-square&logo=github&label=CodeQL"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/actions/workflows/swiftlint.yml"><img alt="SwiftLint" src="https://img.shields.io/github/actions/workflow/status/gpicchiarelli/ChitarraTune/swiftlint.yml?branch=main&style=flat-square&logo=github&label=SwiftLint"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Release" src="https://img.shields.io/github/v/release/gpicchiarelli/ChitarraTune?include_prereleases&style=flat-square&label=release"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/gpicchiarelli/ChitarraTune/total?style=flat-square&label=downloads"></a>
</p>

<p>
  <img alt="Version 2.0.0" src="https://img.shields.io/badge/version-2.0.0-4F46E5?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="Xcode 26+" src="https://img.shields.io/badge/Xcode-26%2B-147EFB?style=flat-square&logo=xcode&logoColor=white">
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-000000?style=flat-square&logo=apple&logoColor=white">
  <img alt="iOS 26+" src="https://img.shields.io/badge/iOS-26%2B-000000?style=flat-square&logo=apple&logoColor=white">
  <img alt="iPadOS 26+" src="https://img.shields.io/badge/iPadOS-26%2B-000000?style=flat-square&logo=apple&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF?style=flat-square">
  <img alt="Swift Package Manager" src="https://img.shields.io/badge/Swift_Package-ChitarraTuneKit-F05138?style=flat-square&logo=swift&logoColor=white">
  <img alt="App Intents" src="https://img.shields.io/badge/Siri_%26_Shortcuts-App_Intents-8E8E93?style=flat-square">
  <img alt="Strict concurrency" src="https://img.shields.io/badge/Concurrency-strict-F05138?style=flat-square">
  <img alt="Swift Testing" src="https://img.shields.io/badge/Tests-Swift_Testing-30B94D?style=flat-square">
</p>

<p>
  <img alt="On-device audio" src="https://img.shields.io/badge/Audio-on--device_only-2EA44F?style=flat-square">
  <img alt="No network" src="https://img.shields.io/badge/Network-none-2EA44F?style=flat-square">
  <img alt="No recording" src="https://img.shields.io/badge/Recording-never-2EA44F?style=flat-square">
  <img alt="Third-party dependencies: 0" src="https://img.shields.io/badge/Third--party_dependencies-0-2EA44F?style=flat-square">
  <img alt="App Sandbox" src="https://img.shields.io/badge/App_Sandbox-enabled-0A84FF?style=flat-square&logo=apple&logoColor=white">
  <img alt="Hardened Runtime" src="https://img.shields.io/badge/Hardened_Runtime-enabled-0A84FF?style=flat-square">
  <img alt="Enhanced Security" src="https://img.shields.io/badge/Enhanced_Security-enabled-0A84FF?style=flat-square">
  <img alt="Privacy manifest" src="https://img.shields.io/badge/Privacy_manifest-included-0A84FF?style=flat-square">
  <img alt="Accessibility" src="https://img.shields.io/badge/Accessibility-VoiceOver-5856D6?style=flat-square">
  <img alt="Languages" src="https://img.shields.io/badge/Languages-English_%26_Italiano-FF9500?style=flat-square">
</p>

<p>
  <a href="LICENSE"><img alt="License: BSD 3-Clause" src="https://img.shields.io/badge/license-BSD_3--Clause-4F46E5?style=flat-square"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/gpicchiarelli/ChitarraTune?style=flat-square"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/graphs/commit-activity"><img alt="Commit activity" src="https://img.shields.io/github/commit-activity/m/gpicchiarelli/ChitarraTune?style=flat-square"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/issues"><img alt="Open issues" src="https://img.shields.io/github/issues/gpicchiarelli/ChitarraTune?style=flat-square"></a>
  <a href="https://github.com/gpicchiarelli/ChitarraTune/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/gpicchiarelli/ChitarraTune?style=flat-square"></a>
  <img alt="Top language" src="https://img.shields.io/github/languages/top/gpicchiarelli/ChitarraTune?style=flat-square">
  <img alt="Repository size" src="https://img.shields.io/github/repo-size/gpicchiarelli/ChitarraTune?style=flat-square">
</p>

<br>

<img src="docs/assets/hero.svg" alt="Illustration of the ChitarraTune dial reading E2 at 82.4 Hz, two cents sharp, inside the green in-tune zone" width="100%">

</div>

<br>

> [!NOTE]
> **Version 2.0** is a ground-up rewrite for iOS 26, iPadOS 26 and macOS 26, free on the App Store (as an unlisted app: it is not in search results, only reachable through its direct link) and as a notarized disk image for the Mac on the [releases page](https://github.com/gpicchiarelli/ChitarraTune/releases). See the [changelog](CHANGELOG.md).

<table>
  <tr>
    <td width="33%" valign="top">
      <h3>Fast and steady</h3>
      YIN pitch detection on an FFT, about forty readings a second. The needle glides, and "in tune" only lights up once the note has really settled.
    </td>
    <td width="33%" valign="top">
      <h3>Yours alone</h3>
      Audio is analysed on the device and never recorded or sent anywhere. The app has no network access at all, and no third-party code.
    </td>
    <td width="33%" valign="top">
      <h3>Everywhere you play</h3>
      One app for Mac, iPhone and iPad, with Siri, Shortcuts, keyboard shortcuts and full Dynamic Type support.
    </td>
  </tr>
</table>

## Features

**Tuning**

- Ten tunings, from Standard to Open A, with automatic string detection or a string you pin yourself
- A4 calibration from 415 to 466 Hz, for baroque pitch, 432 or a friend's out-of-tune piano
- Note names in English (`C D E F G A B`) or fixed-do solfège (`Do Re Mi Fa Sol La Si`); *Automatic* follows your language
- Dial or bar gauge, with a green zone of ±5 cents

**Inputs**

- Pick any microphone or audio interface on the Mac; plug and unplug live without restarting
- One tuner per window on the Mac, each with its own input and tuning

**Considerate**

- Relaxes the analysis rate in Low Power Mode or under thermal pressure
- Stops listening after a period of silence (one, three or five minutes, or never)
- No timers or polling while idle; the mic is released the moment you stop

**Accessible**

- VoiceOver labels, values and hints; an announcement when a string is in tune
- Dynamic Type, Reduce Motion, and a haptic tick where the hardware supports it

## Tunings

| Tuning | Strings, low to high |
| :-- | :-- |
| Standard | E · A · D · G · B · E |
| Half step down | E♭ · A♭ · D♭ · G♭ · B♭ · E♭ |
| Full step down | D · G · C · F · A · D |
| Drop D | D · A · D · G · B · E |
| Drop C | C · G · C · F · A · D |
| DADGAD | D · A · D · G · A · D |
| Open D | D · A · D · F♯ · A · D |
| Open G | D · G · D · G · B · D |
| Open E | E · B · E · G♯ · B · E |
| Open A | E · A · E · A · C♯ · E |

## How it works

```
microphone → input tap → sliding window → noise gate → YIN (FFT) → string → smoothing → stability → hold → gauge
```

A pitch detector that costs almost nothing is what makes a tuner feel instant. ChitarraTune computes the YIN difference function through the frequency domain with Accelerate: about 16 µs per analysis on an Apple M4, roughly 65 times faster than the direct loop it replaced (about 1.06 ms). When you pin a string, the search narrows to a window around it, which rules out octave errors by construction.

Real steel strings are slightly inharmonic, and that pulls a period detector a few cents sharp. So once YIN has found the period, ChitarraTune measures it again on a band-passed copy of the signal that keeps only the fundamental and part of the second partial, one filter per string, running on the live stream. The whole reading stays well under a tenth of a millisecond, and on a modelled steel string the typical error is below one cent.

The code is split so that the interesting part can be tested without a microphone:

| Layer | What it does |
| :-- | :-- |
| **TunerCore** | Pitch maths, tunings, the YIN detector and the tuning engine. Pure Swift, no I/O. |
| **TunerAudio** | Microphone capture, permission and input discovery, behind protocols. |
| **TunerFeature** | The observable state the interface renders, and your preferences. |
| **App** | SwiftUI screens, menu commands, Settings and App Intents. |

Concurrency is explicit: capture and DSP are actors, the interface is `@MainActor`, and a generation counter makes sure a slow permission prompt can never start a session you already cancelled. The details are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Siri & Shortcuts

| Action | What it does |
| :-- | :-- |
| **Start tuning** | Opens the app and starts listening (a microphone needs the foreground) |
| **Stop tuning** | Stops listening |
| **Set tuning** | Chooses one of the ten tunings |
| **Set reference pitch** | Sets A4, 415–466 Hz |
| **Pick a string** | Pins string 1–6, or returns to automatic |
| **Choose input** | Selects a microphone or interface |

Try *"Start tuning in ChitarraTune"* or add the actions to your own shortcuts. The **Start Tuning** control can go in Control Center, on the Lock Screen or on the Action Button (iPhone, iPad), and in Control Center or the menu bar (Mac).

## Keyboard shortcuts <sub>macOS</sub>

| Shortcut | Action |
| :-- | :-- |
| <kbd>⌘</kbd> <kbd>L</kbd> | Start or stop listening |
| <kbd>⌘</kbd> <kbd>0</kbd> | Automatic string detection |
| <kbd>⌘</kbd> <kbd>1</kbd> … <kbd>⌘</kbd> <kbd>6</kbd> | Pin a string |
| <kbd>⌘</kbd> <kbd>N</kbd> | New tuner window |
| <kbd>⌘</kbd> <kbd>,</kbd> | Settings |

## Requirements

- **macOS 26** (Tahoe), **iOS 26** or **iPadOS 26**
- **Xcode 26** or later to build

## Install

**iPhone and iPad** are on the App Store, free (an unlisted app: it is not in search results, only reachable through its direct link).

**Mac**, outside the store: download `ChitarraTune-<version>.dmg` from the [releases page](https://github.com/gpicchiarelli/ChitarraTune/releases), open it, and drag **ChitarraTune** onto **Applications**. Both the disk image and the app inside are Developer ID signed, notarized and stapled, so nothing warns even if you have never been online.

To check what you downloaded before opening it:

```bash
shasum -a 256 -c ChitarraTune-<version>.dmg.sha256
spctl --assess --type open --context context:primary-signature -v ChitarraTune-<version>.dmg
```

## Getting started

```bash
git clone https://github.com/gpicchiarelli/ChitarraTune.git
cd ChitarraTune
open ChitarraTune.xcodeproj
```

Choose the **ChitarraTune** scheme and a destination (*My Mac*, an iPhone or an iPad), then run.

**Signing.** The project uses automatic signing with the maintainer's team. To build with your own, create `Config/Local.xcconfig` (ignored by git):

```
DEVELOPMENT_TEAM = YOURTEAMID
```

**Tests.** The package tests need no microphone and no simulator:

```bash
swift test --package-path Packages/ChitarraTuneKit
```

**Command line, without signing.** Good for a compile check:

```bash
xcodebuild -project ChitarraTune.xcodeproj -scheme ChitarraTune \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<details>
<summary><b>Releases and notarization</b></summary>

<br>

Pushing a tag such as `v2.0.0` (from a commit on `main`) runs the [release workflow](.github/workflows/release.yml): it runs the tests, builds and signs the app with your Developer ID certificate, checks the Hardened Runtime flag and the entitlements, notarizes and staples it, then wraps it in a disk image with an `Applications` symlink, signs the image under its own identifier (`com.chitarratune.app.dmg`), notarizes and staples the image too, and publishes `ChitarraTune-<version>.dmg` with a SHA-256 checksum and a build-provenance attestation. Two notarizations, one artifact; the rules are in [ADR 0014](docs/adr/0014-disk-image-distribution.md).

Signing needs repository secrets; the full list and the reasoning are in [`CODE_SIGNING.md`](CODE_SIGNING.md). Without them the workflow refuses to publish, unless you start it by hand and explicitly allow an unsigned build.

An unsigned disk image makes Gatekeeper warn. Verify the SHA-256 checksum, then use **Right-click → Open** once.

</details>

## Privacy & security

ChitarraTune listens to your guitar to measure its pitch, and that is all it does with the microphone.

- **On-device.** Samples live in a short in-memory buffer and are discarded after analysis. Nothing is recorded, stored or sent.
- **No network.** No networking code, and the sandbox network entitlements are off.
- **Least privilege.** macOS App Sandbox with a single resource entitlement, audio input. The permission prompt appears when you ask the tuner to listen.
- **Hardened.** Hardened Runtime and Xcode Enhanced Security.
- **Nothing to inherit.** No third-party dependencies, and every GitHub Action is pinned to a commit SHA.
- **A privacy manifest** declares no tracking and no collected data.

The full policy is in [`PRIVACY.md`](PRIVACY.md). Found a vulnerability? Please report it privately; see [`SECURITY.md`](SECURITY.md).

## Project layout

```
ChitarraTune/
├── App/                    SwiftUI app for macOS, iOS and iPadOS
│   ├── Tuner/              dial, bar, note read-out, string selector, window, commands
│   ├── Settings/           settings, About, license
│   ├── Intents/            Siri and Shortcuts
│   ├── DesignSystem/       colours, formatting, tuning names
│   └── Resources/          string catalogs, assets, privacy manifest
├── Shared/                 code shared by the app and the extension (Start Tuning intent)
├── Controls/               WidgetKit extension: the Start Tuning system control
├── AppStore/               store listing (en, it), review notes, screenshots
├── Config/                 build settings, entitlements, Info.plists, export options
├── Packages/ChitarraTuneKit/
│   ├── Sources/TunerCore/      pitch maths, tunings, YIN, tuning engine
│   ├── Sources/TunerAudio/     capture, permission, input discovery
│   ├── Sources/TunerFeature/   observable models and settings
│   └── Tests/                  Swift Testing suites
└── docs/                   architecture, accessibility, assets
```

## Documentation

| | |
| :-- | :-- |
| [Architecture](docs/ARCHITECTURE.md) | Layers, signal path, concurrency model |
| [Decisions](docs/adr/README.md) | Binding architecture decision records, each enforced by a test |
| [Accessibility](docs/ACCESSIBILITY.md) | What is implemented and what is not |
| [Platforms](PLATFORMS.md) | Requirements and per-platform behaviour |
| [Code signing](CODE_SIGNING.md) | Entitlements, signing, notarization, secrets |
| [Apple compliance](APPLE_COMPLIANCE.md) | App Store readiness |
| [App Store submission](AppStore/README.md) | Listing, submission and unlisted distribution |
| [Device test plan](docs/DEVICE_TEST_PLAN.md) | What to check on real hardware before each release |
| [Support](SUPPORT.md) | How to get help |
| [Changelog](CHANGELOG.md) | What changed |
| [Contributing](CONTRIBUTING.md) | Ground rules and how to help |
| [Security policy](SECURITY.md) | How to report a vulnerability |
| [Privacy](PRIVACY.md) | What the app does with your data (nothing) |
| [Contributors](CONTRIBUTORS.md) | Who made this |

## Contributing

Issues and pull requests are welcome, in English or Italian. Start with [`CONTRIBUTING.md`](CONTRIBUTING.md): it lists the few rules that keep the app small and private. Bugs and ideas go through the [issue forms](https://github.com/gpicchiarelli/ChitarraTune/issues/new/choose).

## License

BSD 3-Clause. See [`LICENSE`](LICENSE) and [`CONTRIBUTORS.md`](CONTRIBUTORS.md).

<sub>Apple, the Apple logo, Mac, macOS, iOS, iPadOS, iPhone, iPad, Xcode, Siri and Shortcuts are trademarks of Apple Inc., registered in the U.S. and other countries and regions. App Store and Mac App Store are service marks of Apple Inc. Swift and the Swift logo are trademarks of Apple Inc. ChitarraTune is an independent project, not affiliated with or endorsed by Apple.</sub>

<br>

## Italiano

<details>
<summary><b>Leggi in italiano</b></summary>

<br>

**ChitarraTune** è un accordatore per chitarra per **Mac, iPhone e iPad**, scritto in Swift 6 e SwiftUI. Misura l'intonazione con l'algoritmo YIN calcolato via FFT, mostra un ago fluido e conferma «intonato» solo quando la nota si è davvero stabilizzata.

> [!NOTE]
> **La versione 2.0** è una riscrittura completa per iOS 26, iPadOS 26 e macOS 26, gratuita sull'App Store (come app non in elenco: non compare nelle ricerche, si raggiunge solo dal suo link diretto) e scaricabile per Mac come immagine disco, autenticata da Apple, dalla [pagina delle release](https://github.com/gpicchiarelli/ChitarraTune/releases).

<!-- app-store-badges:it:start -->
<!-- Official App Store badges: Scripts/app-store-badges.sh <App Store ID> adds them once the app is live. -->
<!-- app-store-badges:it:end -->

**Caratteristiche**

- Dieci accordature, da Standard a Open A, con riconoscimento automatico della corda o corda fissata a mano
- Calibrazione del La (A4) da 415 a 466 Hz
- Nomi delle note in inglese o in solfeggio (Do Re Mi Fa Sol La Si), con modalità *Automatica* che segue la lingua del sistema
- Quadrante o barra, con zona verde di ±5 cent
- Scelta del microfono o dell'interfaccia audio su Mac, anche collegandola a caldo; una finestra per ogni accordatore
- Risparmio energetico: analisi più rada in Modalità Risparmio Energetico, arresto dopo un periodo di silenzio, nessun polling
- Accessibilità: VoiceOver, Dynamic Type, Riduci Movimento
- Siri e Comandi Rapidi: avvia e ferma l'accordatura, scegli accordatura, corda, ingresso e frequenza di riferimento

**Privacy.** L'audio viene analizzato sul dispositivo e non viene mai registrato né inviato: l'app non ha alcun accesso alla rete e non usa codice di terze parti. Sandbox, Hardened Runtime ed Enhanced Security sono attivi. Vedi [`SECURITY.md`](SECURITY.md) per segnalare una vulnerabilità in privato.

**Installare su Mac.** Scarica `ChitarraTune-<versione>.dmg` dalla [pagina delle release](https://github.com/gpicchiarelli/ChitarraTune/releases), aprilo e trascina **ChitarraTune** su **Applicazioni**. Sia l'immagine disco sia l'app dentro sono firmate, autenticate e con il ticket applicato, quindi nessun avviso anche senza connessione.

**Requisiti.** macOS 26, iOS 26 o iPadOS 26; Xcode 26 o successivo.

**Compilare.**

```bash
git clone https://github.com/gpicchiarelli/ChitarraTune.git
cd ChitarraTune
open ChitarraTune.xcodeproj
```

Scegli lo scheme **ChitarraTune** e una destinazione, poi avvia. Per usare il tuo team di firma crea `Config/Local.xcconfig` con `DEVELOPMENT_TEAM = TUOTEAMID` (il file è ignorato da git). I test del pacchetto non richiedono microfono:

```bash
swift test --package-path Packages/ChitarraTuneKit
```

**Licenza.** BSD 3-Clause, vedi [`LICENSE`](LICENSE).

</details>

<br>

<div align="center">
  <sub>Made with Swift, SwiftUI and Accelerate &nbsp;·&nbsp; © 2025–2026 ChitarraTune contributors</sub>
</div>
