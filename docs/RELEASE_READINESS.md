# Release readiness

What still stands between this repository and a public release of ChitarraTune 2.0.0, on each channel, as of 19 September 2026. Update this page whenever an item changes state; delete it once 2.0.0 is out and move anything left into issues.

**Legend:** ⛔ blocks the release · ⚠️ must be done before release · ✅ done

## Summary

| Channel | State | Blocked by |
| :-- | :-- | :-- |
| App Store — iPhone and iPad | Not ready | [B1](#b1-a-paid-apple-developer-program-team), [B2](#b2-release-secrets), [B3](#b3-app-store-connect-record), [V1–V3](#validation-on-real-hardware) |
| App Store — Mac | Not ready | B1, B2, B3, [B4](#b4-mac-screenshots), V1–V3 |
| Developer ID — Mac disk image | Not ready | B1, B2, [B5](#b5-a-first-end-to-end-release), V1 |

The code, the build and the checks are ready: what is missing is the Apple account, its credentials, and evidence from real guitars.

## Blockers

### B1. A paid Apple Developer Program team ⛔

The signing team in `Config/Base.xcconfig`, `7722WYMVXU`, is a **personal team** (its certificate reads *O=GIACOMO PICCHIARELLI*). A personal team:

- cannot sign the iOS app at all, because it cannot grant the Enhanced Security capability (Xcode: *"Personal development teams … do not support the Enhanced Security capability"*), so the app cannot even be installed on an iPhone for testing;
- cannot create a *Developer ID Application* certificate, so the Mac disk image cannot be signed or notarized;
- has no access to App Store Connect.

**Action:** enroll in the Apple Developer Program. If the new team has another Team ID, replace `7722WYMVXU` in `Config/Base.xcconfig` and `AppStore/README.md`. Enhanced Security stays on: it is not relaxed to suit a personal team ([ADR 0003](adr/0003-least-privilege-and-platform-security.md)).

### B2. Release secrets ⛔

The repository has no secrets configured, so the release workflow would refuse to publish. **Action:** set `APPLE_TEAM_ID`, `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_KEY_P8`, `MACOS_CERT_P12` and `MACOS_CERT_PASSWORD` as described in [CODE_SIGNING.md](CODE_SIGNING.md#release-signing-ci).

### B3. App Store Connect record ⛔

**Action:** register `com.chitarratune.app` and `com.chitarratune.app.controls`, create the app record with the iOS and macOS platforms, English (U.S.) and Italian, and the API key with the *App Manager* role ([AppStore/README.md](../AppStore/README.md#one-time-setup)).

### B4. Mac screenshots ⛔

The Mac App Store needs Mac screenshots; only iPhone and iPad ones exist, and they predate the latest interface changes. **Action:** run `Scripts/screenshots.sh` (it produces iPhone 6.9″, iPad 13″ and Mac, in English and Italian) and upload them.

### B5. A first end-to-end release ⛔

The current release workflow has never run: its last runs are from the 2025 pipeline. Signing, both notarizations, the disk image, the attestation and the App Store upload have only been checked piece by piece, ad hoc. **Action:** once B1 and B2 are done, push a pre-release tag such as `v2.0.0-rc.1`. Pre-releases go to the Developer ID channel only, so this exercises signing, notarization and the disk image without touching the App Store. Then install the disk image on a Mac that has never seen the app.

## Validation on real hardware

### V1. Accuracy against a reference tuner ⚠️

Accuracy is proven on modeled strings only ([ACCURACY.md](ACCURACY.md)); the recording corpus is empty. The first field test, an electric guitar through a quiet amplifier into an iMac, found that the top strings did not register. The adaptive noise gate fixes that on modeled signals but has not been re-tested on the instrument.

**Action:** follow the *Tuning* and *Field session* sections of the [device test plan](DEVICE_TEST_PLAN.md) with a strobe tuner or a tone generator as the reference, and add at least one recording per string of an acoustic and an electric guitar to the corpus with `Scripts/add-recording.sh`.

### V2. The device test plan ⚠️

Never run end to end. **Action:** run the [device test plan](DEVICE_TEST_PLAN.md) on the TestFlight build of every release candidate, on the devices it lists, and record the results in the release issue.

### V3. Assistive technologies on device ⚠️

Xcode's accessibility audit runs on every screen in CI, but VoiceOver, Voice Control and Switch Control have not been used on a device. **Action:** the *Accessibility* section of the device test plan. Declare in App Store Connect's accessibility labels only the features checked there.

### V4. Update rate on real devices ⚠️

In manual rendering the audio engine delivers 100 ms buffers although the tap asks for about 23 ms. Measurements do not depend on it, but the needle would update about ten times a second instead of forty. **Action:** read the `stream:` line of *Copy Diagnostics* after a session on each device class; if callbacks are near 100 ms, lower the I/O buffer duration.

## Store listing and legal

| Item | State |
| :-- | :-- |
| Privacy policy | ✅ [PRIVACY.md](../PRIVACY.md), public, English and Italian; matches the privacy manifest and the *Data Not Collected* label |
| Support page and contact | ✅ [SUPPORT.md](../SUPPORT.md), with an email address. A dedicated address instead of a personal one is optional |
| Description, keywords, promotional text, release notes | ✅ English (U.S.) and Italian, checked by `AppStoreMetadataTests` |
| Review notes | ✅ `AppStore/review/notes.txt`: no account needed, how to test without a guitar |
| Age rating | ⚠️ Answer *None* everywhere in App Store Connect → 4+ |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` |
| Accessibility labels in App Store Connect | ⚠️ After V3 |
| Unlisted distribution | ⚠️ Requested after the first approval ([AppStore/README.md](../AppStore/README.md#unlisted-distribution)) |
| License and trademarks | ✅ BSD 3-Clause, *ChitarraTune contributors*; Apple trademark notice in the README |
| Marketing URL | ✅ The GitHub repository. A landing page is optional |

## Already in place

- **Privacy and security:** no network, no recording in any build, App Sandbox with audio input only, Hardened Runtime, Enhanced Security, pointer authentication, no third-party code. All of it is enforced by tests ([ADR 0002](adr/0002-audio-never-leaves-memory.md), [ADR 0003](adr/0003-least-privilege-and-platform-security.md)).
- **Measurement:** frozen golden readings, an accuracy envelope, and invariance to device callback sizes, mains hum and Low Power Mode ([ADR 0008](adr/0008-measurement-integrity.md)).
- **Quality gate:** 100 % line coverage outside the hardware boundary, warnings as errors, strict SwiftLint, UI tests with the accessibility audit on iPhone, iPad and Mac ([ADR 0009](adr/0009-quality-gate-and-change-process.md)).
- **Release pipeline:** every push builds the Mac app and its disk image exactly as a release and checks them as notarization and App Review would ([ADR 0013](adr/0013-release-readiness.md), [ADR 0014](adr/0014-disk-image-distribution.md)).
- **Localization:** English and Italian throughout: app, permission text, Siri phrases, store listing, policies.

## Known limitations to state publicly

- ChitarraTune tunes one string at a time; it does not analyze chords.
- Accuracy is established on modeled strings: 0.16 cent median error on the reference set, 0.3–0.4 cent typical in everyday conditions, about 1 cent for very stiff strings and very soft plucks ([ACCURACY.md](ACCURACY.md)).
- On a device whose audio callbacks are long, the needle updates less often (V4).

## Release day, in order

1. `Scripts/verify.sh --release` on a clean `main`, and a green Gate on GitHub.
2. `CHANGELOG.md`: turn *Unreleased* into `2.0.0` with the date; `Scripts/bump-version.sh 2.0.0`; update `AppStore/metadata/*/release_notes.txt`.
3. Tag `v2.0.0` and push it. The release workflow publishes the notarized disk image and uploads both App Store builds.
4. TestFlight: run the device test plan on both builds.
5. App Store Connect: screenshots, metadata, accessibility labels, review notes, *Manually release this version*; submit iOS and macOS.
6. After approval: request unlisted distribution, then release.
7. Once live: `Scripts/app-store-badges.sh <Apple ID>` adds the official badges to the README.
