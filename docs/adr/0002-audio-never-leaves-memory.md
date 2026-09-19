# ADR 0002: Audio never leaves memory

Status: Accepted (2026-09-19)

## Context

The app listens to the microphone. Users hand it that access on the promise in [PRIVACY.md](../../PRIVACY.md): audio is analysed in memory and discarded. A tuner has no reason to keep sound, and any file, export or upload of audio would break that promise, the App Store privacy label and the user's trust, whatever the intent (a debug aid, a test fixture, a support request).

## Decision

1. The app MUST NOT record, store, export, share or transmit audio, in any build configuration, Debug included.
2. Samples MUST live only in the analysis window of `TuningEngine` and the chunk in flight, and be overwritten as new audio arrives. Nothing MUST copy them elsewhere.
3. Source code MUST NOT use audio-file, recording, file-writing, export or sharing APIs (`AVAudioRecorder`, `AVAudioFile`, `ExtAudioFile`, `AVAssetWriter`, `fileExporter`, `ShareLink`, `Transferable`, `write(to:)`, `FileHandle`…), and MUST NOT contain a WAV/RIFF writer.
4. Only `EngineAudioCapture.swift` MAY install an input tap.
5. Diagnostics MAY describe the stream (sample rate, callback sizes, analyses per second, lost audio), never its content (see ADR 0004).
6. Recordings for the test corpus MUST be made with a separate recorder and added with `Scripts/add-recording.sh`.

## Consequences

- Real-hardware accuracy is proven with recordings made outside the app, with a reference tuner's reading as ground truth.
- A field-testing feature that needs audio is out of scope by design.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ArchitecturePolicyTests.swift` (audio never leaves memory) scans every source file of the app, the extension and the package.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (no audio-file or network APIs, no network entitlement, privacy manifest collects nothing).
