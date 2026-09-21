# Changelog

All notable changes to ChitarraTune, for the people who use it. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/). The engineering history is in the commit log.

## [Unreleased]

**1.0.0** is the first release of ChitarraTune: free on the App Store, for iPhone, iPad and Mac, as an unlisted app, and on the Mac also outside the store as a notarized disk image. It requires macOS 27, iOS 27 or iPadOS 27.

### Added

- **iPhone and iPad**, alongside the Mac, in one app.
- **Ten tunings:** Standard, Half step down, Full step down, Drop D, Drop C, DADGAD, Open D, Open G, Open E and Open A, with automatic string detection or a pinned string.
- **Dial or bar gauge**, and note names in English or fixed-do solfège, chosen automatically from your language.
- **One tuner per window on the Mac**, each with its own input and tuning; any microphone or audio interface, plugged in while you tune, on the channel your guitar is actually on.
- **Siri and Shortcuts** in English and Italian: start and stop tuning, choose a tuning, a string, an input or the reference pitch. A **Start Tuning** control for Control Center, the Lock Screen and the Action Button on iPhone and iPad, and Control Center and the menu bar on the Mac.
- **A screen that explains why the tuner needs the microphone** before the system asks, and one that says what to do if access was denied.
- **Considerate by default:** the tuner stops listening after a period of silence (one, three or five minutes, or never), analyzes less often in Low Power Mode or when the device is hot, and on iPhone and iPad resumes by itself after a phone call or Siri.
- **Accessibility:** VoiceOver speaks notes as words ("E flat, octave 2") and announces when a string is in tune; Dynamic Type up to the largest sizes; Reduce Motion; Increase Contrast; full keyboard control; haptic feedback.
- **Diagnostics you can share:** *Copy Diagnostics* in About gathers the app's own recent log and a summary of earlier crashes, without audio or personal data, for a bug report.
- **A user guide** in English and Italian: in the Mac app under Help ▸ ChitarraTune Help (⌘?), searchable in the Help Viewer and available offline; on iPhone and iPad from Settings ▸ About.
- A new icon for Liquid Glass, in the default, dark, clear and tinted appearances.
- **Accurate on real strings.** Steel strings are slightly inharmonic, which pulls a naive reading one to eight cents sharp; ChitarraTune measures the fundamental of the string itself. On the reference signals the median error is 0.16 cent ([ACCURACY.md](docs/ACCURACY.md)).
- **Steady.** "In tune" lights up only once the note has stayed within ±5 cents for six analyses in a row, and stays lit until it drifts beyond ±7. A string that is dying away does not jump an octave or onto another string.
- **Undisturbed by mains hum or Low Power Mode:** neither biases the low strings, and a reading never depends on the audio hardware's buffer size.
- **Soft sources are heard.** The tuner learns how quiet your room is and listens down to −64 dBFS there, so an amplifier at low volume or the top strings into a laptop's microphone need no extra input gain. It decides whether you are playing from the range a string of your tuning could be in, so an amplifier's idle hum, a fan or a desk no longer drowns out the thin strings above them.
- **Reference pitch from 415 to 466 Hz**, for baroque and for ensembles that tune elsewhere.
- **On the Mac outside the store**, the download is a notarized disk image, `ChitarraTune-X.Y.Z.dmg`: open it and drag the app onto Applications.

### Security

- **Nothing leaves your device.** Audio is analyzed in memory and never recorded, stored or sent; the app has no network access and no third-party code.
- App Sandbox with a single resource, the microphone; Hardened Runtime, Enhanced Security and pointer authentication on everything that ships.
- A privacy manifest that declares no tracking and no collected data.
- Signed, notarized releases with a SHA-256 checksum and a build-provenance attestation.

### For developers

- The code is a local Swift package, `ChitarraTuneKit` (`TunerCore`, `TunerAudio`, `TunerFeature`), under one multiplatform SwiftUI app, in Swift 6 with complete strict concurrency.
- Binding [architecture decision records](docs/adr/README.md), each enforced by a test; 100 % line coverage outside the hardware boundary; golden readings and an accuracy envelope that protect every measurement.
- Every push runs the tests, UI tests with Xcode's accessibility audit on iPhone, iPad and Mac, and builds the Mac app and its disk image exactly as a release, checked as notarization and App Review would.

[Unreleased]: https://github.com/gpicchiarelli/ChitarraTune/commits/main
