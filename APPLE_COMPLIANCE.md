# Apple compliance

What is in place for the App Store, Human Interface Guidelines and system requirements, and what still has to be done at submission time.

## In place

| Area | State |
| --- | --- |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy`: no tracking, no collected data, `UserDefaults` accessed for the app's own settings (reason `CA92.1`). |
| Microphone permission | `NSMicrophoneUsageDescription` states that audio is analysed on the device and never recorded or sent anywhere; localized in `InfoPlist.xcstrings`. By default the prompt appears only once the user asks the tuner to listen (Start button or the Start action). |
| Sandbox | macOS App Sandbox with the audio-input resource only; network connections disabled. |
| Encryption export | `ITSAppUsesNonExemptEncryption = NO` (the app has no networking and no cryptography). |
| Category | `LSApplicationCategoryType = public.app-category.music`. |
| Hardening | Hardened Runtime and Xcode Enhanced Security (see [CODE_SIGNING.md](CODE_SIGNING.md)). |
| Localization | English and Italian: app strings, permission text and Siri phrases. |
| Copyright | `NSHumanReadableCopyright` in the Info.plist; the license is shown in the app (macOS: Help → License). |
| Background behaviour | No `UIBackgroundModes`. On iOS listening stops when the app leaves the foreground. |
| Accessibility | See [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md). |

## To do at submission

- **Age rating:** answer the questionnaire; the app has no sensitive content.
- **Privacy nutrition label:** *Data Not Collected*.
- **Privacy policy URL** (App Store Connect requires one): use the published `PRIVACY.md`.
- **Support URL and (optional) marketing URL** for the store listing.
- **Screenshots** for each device family.
- **macOS distribution outside the Mac App Store** needs a Developer ID signature and notarization; the release workflow does both when its secrets are configured.

## Logging

The app uses `os.Logger` (subsystem `com.chitarratune.app`). Dynamic strings are redacted by default; the app marks only error descriptions and failure codes as public. No audio data is logged.
