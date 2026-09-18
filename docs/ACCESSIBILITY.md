# Accessibility

This page describes what the code does today. It is not a certification: the behaviour has been written against Apple's accessibility APIs but has not yet been through a full VoiceOver audit on device.

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

## Known gaps

- No full VoiceOver, Voice Control and Switch Control pass on device yet.
- No automated accessibility audit in CI.
- Colour is used for feedback (green, amber, red). The cents value and the note are always shown as text as well, but contrast under *Increase Contrast* has not been measured.

## Testing checklist

- [ ] Navigate the whole app with VoiceOver only (macOS and iOS).
- [ ] Set the largest Dynamic Type sizes and check nothing is clipped.
- [ ] Turn on *Reduce Motion* and confirm the gauge does not animate.
- [ ] Turn on *Increase Contrast* and *Differentiate Without Color*.
- [ ] Drive the tuner with the keyboard only.
- [ ] Run Xcode's Accessibility Inspector on each screen.
