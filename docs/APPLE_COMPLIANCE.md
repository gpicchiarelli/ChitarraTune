# Apple compliance

How ChitarraTune meets the App Store Review Guidelines, the Human Interface Guidelines and the platform requirements on iPhone, iPad and Mac, and what is left to do by hand at submission. The runbook is [AppStore/README.md](../AppStore/README.md); what still blocks the first release is in [RELEASE_READINESS.md](RELEASE_READINESS.md).

## In place

| Area | State |
| :-- | :-- |
| Distribution | Free. One App Store record for iPhone, iPad and Mac (bundle identifier `com.chitarratune.app`), distributed as an unlisted app; on the Mac also a Developer ID disk image, notarized. |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy`: no tracking, no collected data; required-reason APIs `UserDefaults` (`CA92.1`) and system boot time (`35F9.1`). A policy test holds the list. |
| Privacy label | *Data Not Collected*. [PRIVACY.md](../PRIVACY.md) is the published policy, in English and Italian; it also covers the diagnostics a user copies and the crash reports Apple provides. |
| Microphone permission | `NSMicrophoneUsageDescription` says audio is analyzed on the device and never recorded or sent, in both languages. The app explains why it needs the microphone on its own screen, and only when the user asks it to listen (HIG, *Requesting permission*). A denied or restricted permission gets a screen that says what to do and opens the right Settings page. |
| Sandbox | App Sandbox on the Mac for the app (audio input only) and the extension (nothing); no network entitlement anywhere. |
| Hardening | Hardened Runtime, Xcode Enhanced Security and pointer authentication for the app and the extension ([CODE_SIGNING.md](CODE_SIGNING.md)). Release builds carry no development entitlement. |
| Release checks | Every push builds the Mac app as a release and checks what notarization and App Review check: identifiers, versions, purpose strings, privacy manifest, architectures, linkage, entitlements ([ADR 0013](adr/0013-release-readiness.md)). |
| Encryption export | `ITSAppUsesNonExemptEncryption = NO`. |
| Category | `public.app-category.music`. |
| Icon | Icon Composer document (`App/Resources/AppIcon.icon`), layered for Liquid Glass: the system renders the default, dark, clear and tinted appearances on iOS, iPadOS and macOS. |
| Launch | Generated launch screen (`UILaunchScreen`), no splash screen. |
| Platforms | Native on each: SwiftUI multiplatform; on the Mac one window per tuner, a Settings scene, menu-bar commands and keyboard shortcuts; on iPad one window in every orientation, Split View and Stage Manager; on iPhone portrait and landscape. No Mac Catalyst, no "Designed for iPad" on Mac or Vision. |
| System integration | Siri and Shortcuts (App Intents, English and Italian phrases); a *Start Tuning* control for Control Center, the Lock Screen and the Action Button (iPhone, iPad) and Control Center and the menu bar (Mac). |
| Background | No `UIBackgroundModes`. On iPhone and iPad listening stops when the app goes to the background, and resumes by itself after a phone call or Siri. |
| Accessibility | VoiceOver, Voice Control labels, Dynamic Type up to the largest accessibility size, Reduce Motion, Increase Contrast color variants, WCAG contrast checked from the asset catalog, Xcode's accessibility audit on every screen in CI ([ACCESSIBILITY.md](ACCESSIBILITY.md)). |
| Localization | English and Italian: app, permission text, control, Siri phrases, store listing, policies. |
| Support | [SUPPORT.md](../SUPPORT.md), with an email address (guideline 1.5). |
| Metadata | `AppStore/metadata`, checked by `AppStoreMetadataTests` for length limits, keywords, forbidden claims and working URLs. |
| Review notes | `AppStore/review/notes.txt`: no account needed, how to test without a guitar. |
| Copyright | `NSHumanReadableCopyright` in the Info.plist; the license is shown in the app. |
| Marketing | App Store badges only as Apple provides them, in English and Italian, linked to the product page, and only once the app is live (`Scripts/app-store-badges.sh`); the README carries Apple's trademark notice. `AppStoreBadgeTests` holds these rules. |
| Logging | `os.Logger`, subsystem `com.chitarratune.app`. Dynamic values are private; errors are public as domain and code only; no audio is ever logged ([ADR 0004](adr/0004-logging-and-diagnostics.md)). |
| Crash and energy data | MetricKit summaries in the app's own log and in *Copy Diagnostics*; Xcode Organizer for the reports users share with developers. No third-party SDK. |

## At submission, by hand

- The one-time setup: app record, identifiers, API key, repository secrets ([AppStore/README.md](../AppStore/README.md#one-time-setup)).
- Age rating questionnaire: *None* everywhere, which gives 4+.
- App Privacy: *No, we do not collect data from this app*.
- Accessibility labels in App Store Connect: declare only what the device test plan has confirmed on device.
- Screenshots for iPhone 6.9″, iPad 13″ and Mac, in English and Italian: `Scripts/screenshots.sh`.
- The [device test plan](DEVICE_TEST_PLAN.md) on the TestFlight build.
- *Manually release this version*, submit, then request unlisted distribution.
- Once live: `Scripts/app-store-badges.sh <Apple ID>` for the README badges.
