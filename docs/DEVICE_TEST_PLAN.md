# Device test plan

Automated tests cover the signal path (synthetic and modeled strings), the presentation model, every screen in demo mode and Xcode's accessibility audit on iPhone, iPad and Mac. What they cannot cover is real hardware: a real microphone, a real guitar, a phone call, VoiceOver on a device. Run this plan on the TestFlight build of every release candidate, before submitting for review. Record the build number, the device and the result of each line in the release issue.

## Field session (debug build from Xcode)

ChitarraTune never records or stores audio, in any build. What it logs is how the device delivers audio: after 3 s of listening, then every minute and when listening stops, e.g. `stream: 48000 Hz, 3.0 s, 141 callbacks of 1024–1024 frames (21.3 ms average), 39.9 analyses/s, 0 discontinuities; no reading: 80 below the gate, 3 unclear, 0 out of range`. When a string does not move the needle, the last part says why: *below the gate* (too quiet for the room), *unclear* (not a clean periodic sound: noise, a buzzing string, two strings at once), *out of range* (more than 300 cents from every string). Read it in Console.app (filter `com.chitarratune.app`, category `capture`) or with *Settings ▸ About ▸ Copy Diagnostics*. Analyses must be ~40/s whatever the callback size (~22/s in Low Power Mode); discontinuities must be 0 in a quiet session.

To turn a real string into a regression test, record it with a separate recorder (Voice Memos, a DAW), never with ChitarraTune:

1. Tune the string with a trusted reference (strobe tuner, or a tone generator and beats) and note its reading in cents: that is the ground truth, never ChitarraTune's own reading.
2. Record one pluck of 2–4 seconds. Note what ChitarraTune showed for the same pluck.
3. `Scripts/add-recording.sh <file> --tuning standard --string 1 --cents <reference reading> --source "<guitar, microphone, room>"` copies it into the corpus as a mono WAV, adds it to the manifest and runs the corpus tests.

A useful first set: every open string of standard tuning in tune (0 ¢), the low E 20 ¢ flat and 20 ¢ sharp, one string at A4 = 442 Hz (`--a4 442`), and the low E played softly into an iPhone's built-in microphone.

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
- [ ] Electric guitar through an amplifier at low volume, heard by a Mac's or an iPhone's built-in microphone in a quiet room: every string, the top two included, moves the needle without raising the input gain. If one does not, *Copy Diagnostics* says why (`no reading: … below the gate, … unclear, … out of range`).

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
- [ ] iPad with a hardware keyboard: the same shortcuts; with Full Keyboard Access, Space activates the focused control.

- [ ] Mac: Help ▸ ChitarraTune Help (⌘?) opens the user guide in the Mac's language, English or Italian; searching for *reference pitch* (*diapason*) finds its page; the guide opens with the Mac offline.
- [ ] iPhone and iPad: Settings ▸ About ▸ User Guide opens the guide in the app's language.

## Accessibility (on device)

- [ ] VoiceOver: every control has a label, value and hint; the note read-out and gauge speak the deviation; *In tune* is announced.
- [ ] Voice Control: "Tap Start Listening", "Tap Auto", "Tap String 3" work.
- [ ] Switch Control reaches every control.
- [ ] Largest accessibility text size: nothing is clipped; the screen scrolls.
- [ ] Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, Smart Invert: everything stays legible, nothing animates with Reduce Motion.
- [ ] Mac: Full Keyboard Access reaches every control.

## Energy and performance

- [ ] Listening for ten minutes: the device does not get warm; Xcode Organizer shows no energy or hang reports for the build after a few days of TestFlight.
- [ ] Low Power Mode: the tuner keeps working (at a lower analysis rate).
- [ ] Leaving the app idle with the auto-stop set to one minute: listening stops, and the notice explains why.

## Localization

- [ ] Device in Italian: the whole app, the permission text, the control and Siri phrases are in Italian; note names use solfège by default.
- [ ] Device in English: English everywhere, letter names by default.
