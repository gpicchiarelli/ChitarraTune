# Apple compliance

What is in place for the App Store Review Guidelines, the Human Interface Guidelines and the platform requirements on iPhone, iPad and Mac, and what is left to do by hand at submission time. The submission runbook is [AppStore/README.md](AppStore/README.md).

## In place

| Area | State |
| --- | --- |
| Distribution | Free. App Store (iPhone, iPad, Mac; one app record, bundle id `com.chitarratune.app`), distributed as an unlisted app; Developer ID with notarization for the Mac outside the store. |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy`: no tracking, no collected data; required-reason APIs `UserDefaults` (`CA92.1`) and system boot time (`35F9.1`). A policy test holds the list. |
| Privacy label | *Data Not Collected*. [PRIVACY.md](PRIVACY.md) is the published policy (English and Italian); it also covers diagnostics the user copies and crash reports Apple provides. |
| Microphone permission | `NSMicrophoneUsageDescription` says audio is analysed on the device and never recorded or sent; localized. The app explains why it needs the microphone on its own screen before the system prompt, only when the user asks it to listen (HIG: *Requesting permission*). A denied or restricted permission gets a screen that says what to do and opens the right Settings page. |
| Sandbox | macOS App Sandbox for the app (audio input only) and the extension (nothing); no network entitlement anywhere. |
| Hardening | Hardened Runtime and Xcode Enhanced Security for the app and the extension (see [CODE_SIGNING.md](CODE_SIGNING.md)). |
| Encryption export | `ITSAppUsesNonExemptEncryption = NO`. |
| Category | `public.app-category.music`. |
| Icon | Icon Composer document (`App/Resources/AppIcon.icon`), layered for Liquid Glass: the system renders the default, dark, clear and tinted appearances on iOS, iPadOS and macOS. |
| Launch | Generated launch screen (`UILaunchScreen`); no splash. |
| Platforms | Native on each: SwiftUI multiplatform, one window per tuner and a Settings scene on the Mac, menu-bar commands and keyboard shortcuts, iPad multitasking in all four orientations, iPhone portrait and landscape. No Catalyst, no "Designed for iPad" on Mac or Vision. |
| System integration | Siri and Shortcuts (App Intents, English and Italian phrases); a *Start Tuning* control for Control Center, the Lock Screen and the Action Button (iPhone, iPad) and Control Center and the menu bar (Mac). |
| Background behaviour | No `UIBackgroundModes`. On iPhone and iPad listening stops when the app goes to the background; after a phone call or Siri it resumes by itself. |
| Accessibility | VoiceOver, Voice Control labels, Dynamic Type up to the largest accessibility size (the screen scrolls), Reduce Motion, Increase Contrast colour variants, WCAG AA contrast checked from the asset catalog, Xcode's accessibility audit on every screen in CI. See [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md). |
| Localization | English and Italian: app, permission text, control, Siri phrases, store listing. |
| Support | [SUPPORT.md](SUPPORT.md) with an email address (guideline 1.5). |
| Metadata | `AppStore/metadata`, checked by `AppStoreMetadataTests` for length limits, keywords, forbidden claims and working URLs. |
| Review notes | `AppStore/review/notes.txt`: no account needed, how to test without a guitar. |
| Copyright | `NSHumanReadableCopyright` in the Info.plist; the licence is shown in the app. |
| Marketing | App Store badges only as Apple provides them (served by Apple's marketing tools, English and Italian artwork, black, 40 pt), linked to the product page and added only once the app is live (`Scripts/app-store-badges.sh`); the README carries Apple's trademark credit line. `AppStoreBadgeTests` holds these rules. |
| Crash and energy data | MetricKit summaries in the app's own log; Xcode Organizer for reports users share with developers. No third-party SDK. |

## To do by hand at submission

- Create the app record and the API key, set the repository secrets ([AppStore/README.md](AppStore/README.md), *One-time setup*).
- Age rating questionnaire: *None* everywhere → 4+.
- Privacy questionnaire: *No, we do not collect data*.
- Screenshots: `Scripts/screenshots.sh`, then upload per device and locale.
- Run the [device test plan](docs/DEVICE_TEST_PLAN.md) on the TestFlight build.
- Choose *Manually release this version*, submit, then request unlisted distribution.
- Once the app is live: `Scripts/app-store-badges.sh <Apple ID>` for the README badges.

## Logging

The app uses `os.Logger` (subsystem `com.chitarratune.app`). Dynamic strings are redacted by default; the app marks only error descriptions and failure codes as public. No audio data is logged.
