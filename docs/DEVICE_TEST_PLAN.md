# Device test plan

Automated tests cover the signal path (synthetic and modelled strings), the presentation model, every screen in demo mode and Xcode's accessibility audit on iPhone, iPad and Mac. What they cannot cover is real hardware: a real microphone, a real guitar, a phone call, VoiceOver on a device. Run this plan on the TestFlight build of every release candidate, before submitting for review. Record the build number, the device and the result of each line in the release issue.

## Devices

| Class | Minimum | Why |
| --- | --- | --- |
| iPhone | one with a single bottom microphone, one Pro model | microphone placement and low-end roll-off differ |
| iPad | one with Stage Manager, one in Split View | window sizes, keyboard, pointer |
| Mac | Apple silicon laptop (built-in mic) and a USB audio interface | input selection, hot-plug, multiple windows |
| Audio | wired headset with microphone, AirPods or other Bluetooth headset | route changes |

## Tuning

- [ ] Standard tuning, automatic mode: each open string is named correctly and reaches *In tune* against a trusted reference (strobe or tone generator), within ±2 cents of it.
- [ ] Low E through the built-in microphone of an iPhone, played softly: the reading is stable and never jumps to another string.
- [ ] Pin string 6 and detune it by a semitone: the needle goes to the end of the scale and comes back as you tune up.
- [ ] Drop D and DADGAD: the low D is named and measured correctly.
- [ ] A4 = 432 Hz and 415 Hz: the targets move accordingly.
- [ ] Let a string ring out completely: the reading holds, dims, and never flips to another note.
- [ ] Electric guitar into an audio interface on the Mac (input 2 of a two-input interface): heard and measured.

## Microphone permission

- [ ] Fresh install: *Start Listening* shows the explanation first; *Continue* brings the system prompt; allowing starts listening.
- [ ] *Not Now* returns to the tuner without asking.
- [ ] Deny in the system prompt: the failure screen offers *Open Settings*, which lands on the right page; allowing there and coming back, *Try Again* works.
- [ ] iPhone with Screen Time restricting the microphone: *Microphone Restricted* is shown, with no retry.

## Interruptions and routes

- [ ] Receive a phone call while listening: listening stops; after hanging up it resumes by itself.
- [ ] Invoke Siri while listening: same.
- [ ] Plug and unplug a wired headset while listening: capture restarts on the new route without an error.
- [ ] Connect AirPods while listening: the tuner keeps working (on the AirPods' microphone or the built-in one).
- [ ] Mac: unplug the selected USB interface: the tuner falls back to the default input.
- [ ] Put the iPhone app in the background while listening: the microphone indicator turns off at once.

## System integration

- [ ] Add the *Start Tuning* control to Control Center (iPhone, iPad, Mac), the Lock Screen and the Action Button: each opens the app and starts listening.
- [ ] *"Start tuning in ChitarraTune"* and *"Stop tuning in ChitarraTune"* with Siri, in English and Italian.
- [ ] Shortcuts app: every ChitarraTune action runs.
- [ ] Mac: Dock menu *Start*/*Stop*, ⌘L, ⌘0, ⌘1–⌘6, ⌘N (two windows with different inputs), ⌘, (Settings).
- [ ] iPad with a hardware keyboard: the same shortcuts and Space to start and stop.

## Accessibility (on device)

- [ ] VoiceOver: every control has a label, value and hint; the note read-out and gauge speak the deviation; *In tune* is announced.
- [ ] Voice Control: "Tap Start Listening", "Tap Auto", "Tap String 3" work.
- [ ] Switch Control reaches every control.
- [ ] Largest accessibility text size: nothing is clipped; the screen scrolls.
- [ ] Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Colour, Smart Invert: everything stays legible, nothing animates with Reduce Motion.
- [ ] Mac: Full Keyboard Access reaches every control.

## Energy and performance

- [ ] Listening for ten minutes: the device does not get warm; Xcode Organizer shows no energy or hang reports for the build after a few days of TestFlight.
- [ ] Low Power Mode: the tuner keeps working (at a lower analysis rate).
- [ ] Leaving the app idle with the auto-stop set to one minute: listening stops, and the notice explains why.

## Localisation

- [ ] Device in Italian: the whole app, the permission text, the control and Siri phrases are in Italian; note names use solfège by default.
- [ ] Device in English: English everywhere, letter names by default.
