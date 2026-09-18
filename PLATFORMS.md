# Supported platforms

ChitarraTune is **one multiplatform target** with a shared code base. There is no separate iOS target.

| Platform | Minimum OS | Notes |
| --- | --- | --- |
| **macOS** | 26 (Tahoe) | App Sandbox |
| **iPhone** | iOS 26 | Portrait and both landscapes |
| **iPad** | iPadOS 26 | All four orientations |

Mac Catalyst and "Designed for iPhone/iPad" on Mac and Vision are switched off (`SUPPORTS_MACCATALYST`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`, `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD`). The bundle identifier is `com.chitarratune.app` on every platform.

Requires **Xcode 26 or later**. The deployment targets are set in `Config/Base.xcconfig`.

## Build

Open `ChitarraTune.xcodeproj`, choose the **ChitarraTune** scheme and a destination: *My Mac*, an iPhone or an iPad (simulator or device).

## Behaviour by platform

| | macOS | iOS / iPadOS |
| --- | --- | --- |
| Windows | One window per tuner (⌘N opens another, each with its own input and tuning); a Settings window; About and License windows | One window; Settings in a sheet |
| Commands | Menu bar commands and keyboard shortcuts | Hardware-keyboard shortcuts on iPad |
| Microphone | Any Core Audio input, chosen from the toolbar, with hot-plug detection | The system route, or one of the available input ports |
| Leaving the app | Keeps listening while the window is open; holds an activity assertion so App Nap does not throttle analysis | Stops listening as soon as the app leaves the foreground (iOS may not record in the background) |
| Screen | Normal | Kept awake while listening |
| Feedback | Visual | Visual and haptic |

## Localization

English and Italian, in string catalogs: `App/Resources/Localizable.xcstrings` (app), `InfoPlist.xcstrings` (permission text) and `AppShortcuts.xcstrings` (Siri phrases). Note names follow the chosen notation (English or fixed-do solfège).

## Icons and assets

`App/Resources/Assets.xcassets` holds the app icon (all iPhone, iPad and Mac sizes plus the 1024 pt marketing icon), the accent colour and the tuner colours (`TuneGreen`, `TuneAmber`, `TuneRed`), each with light, dark and high-contrast variants.
