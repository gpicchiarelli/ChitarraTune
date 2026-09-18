# Architecture

ChitarraTune is a single multiplatform SwiftUI app (macOS, iPhone, iPad) on top of a local Swift package, **ChitarraTuneKit**, that holds everything that is not user interface.

```
┌───────────────────────────────────────────────────────────────┐
│ App/                  SwiftUI screens · App Intents · resources │
├───────────────────────────────────────────────────────────────┤
│ TunerFeature          @Observable models · settings · hub       │
├───────────────────────────────────────────────────────────────┤
│ TunerAudio            capture · permission · input discovery    │
├───────────────────────────────────────────────────────────────┤
│ TunerCore             pitch maths · tunings · YIN · engine      │  ← pure, no I/O
└───────────────────────────────────────────────────────────────┘
```

Dependencies only point downwards. `TunerCore` imports Foundation and Accelerate and nothing else, so the whole signal path can be tested with synthetic sine waves and no microphone.

## Modules

| Module | Responsibility | Key types |
| --- | --- | --- |
| **TunerCore** | Notes, tunings, frequency ↔ cents maths, pitch detection and the tuning pipeline. | `Note`, `Tuning`, `PitchMath`, `PitchDetector`, `CrossCorrelator`, `TuningEngine` |
| **TunerAudio** | Turns a microphone into a stream of mono audio chunks; microphone permission; the list of inputs and its changes. | `EngineAudioCapture`, `SystemMicrophoneAuthorization`, `SystemAudioInputs`, `CaptureFailure` |
| **TunerFeature** | The state the UI renders and the user's preferences. | `TunerModel`, `TunerHub`, `TunerSettings`, `PowerProfile`, `TunerProcessor` |
| **App** | Screens (dial, bar, note read-out, string selector), menu commands, Settings, About, Siri and Shortcuts. | `TunerScreen`, `TunerCommands`, `TunerIntents` |

`TunerAudio` exposes protocols (`AudioCapturing`, `MicrophoneAuthorizing`, `AudioInputProviding`) so `TunerModel` can be driven by test doubles and by a synthetic guitar (`SimulatedAudioCapture`).

## Signal path

```
microphone
  → AVAudioEngine input tap (1024 frames, channel 0)      TunerAudio
  → AsyncThrowingStream<AudioChunk>  (newest 8 kept)
  → ring buffer                                           TunerCore
  → noise gate with hysteresis
  → YIN: FFT cross-correlation (Accelerate) → CMNDF → parabolic interpolation
  → string selection (automatic, or pinned to one string)
  → smoothing → in-tune stability with hysteresis → hold
  → TunerFrame → TunerModel → SwiftUI
```

- **Detector.** The difference function is computed as `E₀ + E_τ − 2·c(τ)` with `c` obtained through the frequency domain, so one analysis costs `O(N log N)` instead of `O(W · lags)`. The search range follows the tuning and A4; pinning a string narrows it to 0.7×–1.5× of that string, which rules out octave errors by construction.
- **Engine parameters.** Noise gate opens at 0.004 RMS and closes at 0.0025; minimum clarity 0.55; deviations beyond ±300 cents are ignored; "in tune" is ±5 cents with 2 cents of exit margin and six consecutive stable analyses; the last reading is held for 0.8 s after the signal fades.
- **Cadence.** One analysis every 25 ms (~40 Hz). In Low Power Mode or under serious thermal pressure `PowerProfile` relaxes this to 45 ms.

## Concurrency model

The package is built in Swift 6 language mode; the app with `SWIFT_STRICT_CONCURRENCY = complete`.

- `EngineAudioCapture` is an **actor**. The audio-thread tap closure touches no actor state; it copies the samples and yields them into a stream.
- `TunerProcessor` is an **actor** that owns the non-`Sendable` `TuningEngine`, so the DSP runs off the main thread with no locks.
- `TunerModel`, `TunerHub` and `TunerSettings` are `@MainActor @Observable`. Properties are written only when the value changes, which keeps SwiftUI redraws to a minimum.
- Session control uses a **generation counter**: every `start()` and `stop()` bumps it, and every asynchronous continuation checks that it still belongs to the current generation before acting. A permission prompt or a slow start that finishes after the user stopped is therefore ignored.
- A route or hardware-format change ends the stream with `CaptureFailure.configurationChanged`; the model restarts capture up to three times before reporting the failure.

## State

`TunerModel.Status` is `idle → starting → listening`, or `failed(CaptureFailure)`. The UI maps failures to text; `CaptureFailure` carries no user-facing strings.

`TunerHub` owns one `TunerModel` per window and remembers which was focused last, so Siri, Shortcuts and menu commands act on the tuner you are looking at. Models are created lazily (which also makes window restoration work) and released, with their audio, when a window closes.

## Preferences

`TunerSettings` persists to `UserDefaults`. The keys `A4`, `tuningPresetID` and `preferredInputUID` are the ones used by 1.x, so calibration and tuning survive the upgrade. A4 is clamped to 415–466 Hz.

## Siri and Shortcuts

App Intents reach the running tuner through `AppDependencyManager` (`@Dependency var hub: TunerHub`). Available actions: start tuning (opens the app, because a microphone needs the foreground), stop tuning, set tuning, set reference pitch, pick a string, choose an input.

## Build configuration

Build settings live in `Config/*.xcconfig`, not in the project file: `Base` (platforms, Swift, security), `Debug`, `Release`, `App`, `UITests`. Signing material and sandbox entitlements are described in [CODE_SIGNING.md](../CODE_SIGNING.md).

## Testing

`swift test --package-path Packages/ChitarraTuneKit` runs the Swift Testing suites for `TunerCore` (notes, tunings, correlator, detector, engine) and `TunerFeature` (model and settings, using test doubles). Anything that needs a real microphone is exercised manually.
