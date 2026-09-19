# Accessibility

This page describes what the code does today. It is not a certification: the behavior has been written against Apple's accessibility APIs but has not yet been through a full VoiceOver audit on device.

## What is implemented

**VoiceOver**

- The gauge is exposed as a single element with a label and a spoken value, and is marked `updatesFrequently` so VoiceOver does not chatter on every update. The dial, bar and background are hidden from the accessibility tree.
- Each string chip has a label (the note), a value ("String 3"), a hint, and the `selected` trait when it is pinned. The "automatic" chip has a hint and the `selected` trait when active.
- The listen button, the tuning picker and the input menu carry labels, values and hints.
- When a string reaches "in tune", the app posts an accessibility announcement (`AccessibilityNotification.Announcement`).

**Motion**

- The dial, the bar and the background read `accessibilityReduceMotion` and disable their animations when it is on.

**Dynamic Type**

- Text scales with the user's size. The string selector switches to a different layout at accessibility sizes, and the large note read-out is capped at `accessibility2` so it always fits.

**Notation**

- Note names can be shown as `C D E F G A B` or as fixed-do solfège (`Do Re Mi Fa Sol La Si`). Automatic follows the system language.

**Haptics**

- Where the device supports it, a haptic confirms "in tune", string selection and start/stop. It can be turned off in Settings.

**Keyboard (macOS)**

| Action | Shortcut |
| --- | --- |
| Start or stop listening | ⌘L |
| Automatic string detection | ⌘0 |
| Pin string 1–6 | ⌘1 … ⌘6 |
| New tuner window | ⌘N |
| Settings | ⌘, |

**Contrast**

- Every color in the asset catalog has light, dark and *Increase Contrast* variants. `ColorContrastTests` computes their WCAG 2.2 contrast against every background the app draws them on (window, grouped form, the tinted washes): text reaches 4.5:1, and 7:1 with *Increase Contrast*; white text sits on opaque fills of at least 5.8:1 (8:1 for the accent); secondary buttons reach 7:1.
- Secondary text uses its own color (`TuneSecondaryLabel`) instead of the system secondary label, which is about 3.4:1 on white.
- Color is never the only signal: every tuning state also has a text label and its own symbol.

**Explaining the microphone**

- Before the system permission prompt, a screen says why the tuner needs the microphone and that audio is never recorded. A denied or restricted permission leads to a screen with the one action that helps.

## Automated checks

`ChitarraTuneUITests` runs Xcode's accessibility audit (element descriptions, hit regions, traits, actions, clipping, Dynamic Type) on the tuner idle and listening, the microphone explanation, the failure screen and Settings, in light and Dark Mode, in landscape and at the largest accessibility text size, on iPhone, iPad and Mac. CI fails on any finding. Contrast is checked exactly by `ColorContrastTests` rather than by the audit's pixel sampling, which flags black text on white next to Liquid Glass. The few accepted exceptions are listed, with their reason, in the test itself (the 88-point note name is capped at *accessibility2* so it fits; decorative ♭/♯; system bar buttons, which use the Large Content Viewer).

## Known gaps

- The on-device pass with VoiceOver, Voice Control and Switch Control is part of the [device test plan](DEVICE_TEST_PLAN.md) for each release; it cannot be automated.

## Testing checklist

- [ ] Navigate the whole app with VoiceOver only (macOS and iOS).
- [ ] Set the largest Dynamic Type sizes and check nothing is clipped.
- [ ] Turn on *Reduce Motion* and confirm the gauge does not animate.
- [ ] Turn on *Increase Contrast* and *Differentiate Without Color*.
- [ ] Drive the tuner with the keyboard only.
- [ ] Run Xcode's Accessibility Inspector on each screen.
