# Hardware boundary

Code in this folder talks to the real audio system: it creates and starts the system's `AVAudioEngine`,
configures the audio session, routes to a device, enumerates Core Audio devices and shows the microphone
permission prompt. Capture itself (tap, channel selection, sample times, teardown, route changes) is
*not* here: `EngineAudioCapture` is tested with an engine in manual rendering mode fed a synthetic signal.
What it does depends on the machine (which devices exist, whether a microphone is granted), so its
coverage would differ between a laptop and a CI runner. It is therefore **excluded from the coverage
gate**. The device-enumeration code is still exercised by the smoke tests in `SystemAudioTests`, and
capture is verified by hand on a device.

Keep it as thin as possible. Anything that can be decided without hardware — channel selection,
buffer conversion, permission-status mapping, failure mapping — belongs outside this folder, where it
is held to 100 % coverage.

Allowed files (enforced by `RepositoryPolicyTests`):

- `EngineAudioCapture+System.swift`
- `MicrophonePrompt.swift`
- `CoreAudioDevices.swift`
- `SystemAudioInputs.swift`
