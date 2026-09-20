# Architecture

ChitarraTune is a single multiplatform SwiftUI app (macOS, iPhone, iPad) on top of a local Swift package, **ChitarraTuneKit**, that holds everything that is not user interface. A small WidgetKit extension, **ChitarraTuneControls**, adds a system control that starts the tuner.

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

The binding decisions behind this document are the [architecture decision records](adr/README.md); where the two differ, the ADR wins and the difference is a bug.

Dependencies only point downwards. `TunerCore` imports Foundation and Accelerate and nothing else, so the whole signal path can be tested with synthetic sine waves and no microphone.

## Modules

| Module | Responsibility | Key types |
| --- | --- | --- |
| **TunerCore** | Notes, tunings, frequency ↔ cents math, pitch detection and the tuning pipeline. | `Note`, `Tuning`, `PitchMath`, `PitchDetector`, `CrossCorrelator`, `PartialFilter`, `PresenceMeter`, `NoiseGate`, `InharmonicityTracker`, `TuningEngine` |
| **TunerAudio** | Turns a microphone into a stream of mono audio chunks; microphone permission; the list of inputs and its changes. | `EngineAudioCapture`, `SystemMicrophoneAuthorization`, `SystemAudioInputs`, `CaptureFailure` |
| **TunerFeature** | The state the UI renders, the user's preferences, and what the device delivers (for diagnostics). | `TunerModel`, `TunerHub`, `TunerSettings`, `PowerProfile`, `TunerProcessor`, `StreamStatistics` |
| **App** | Screens (dial, bar, note read-out, string selector), the microphone explanation, menu commands, Settings, About, Siri and Shortcuts. | `TunerScreen`, `MicrophonePrimer`, `TunerCommands`, `TunerIntents` |
| **Shared** | Code compiled into both the app and the extension. | `StartTuningIntent` |
| **Controls** (extension) | The *Start Tuning* control for Control Center, the Lock Screen and the Action Button (iPhone, iPad) and Control Center and the menu bar (Mac). | `StartTuningControl` |

`TunerAudio` exposes protocols (`AudioCapturing`, `MicrophoneAuthorizing`, `AudioInputProviding`) so `TunerModel` can be driven by test doubles and by a synthetic guitar (`SimulatedAudioCapture`).

## Signal path

```
microphone
  → AVAudioEngine input tap (1024 frames requested; the system may deliver more; loudest channel) TunerAudio
  → AsyncThrowingStream<AudioChunk>  (newest 8 kept, each stamped with its sample time)
  → TunerProcessor actor: the whole loop runs here, off the main actor   TunerFeature
  → analysis window (history discarded on a sample-time gap)            TunerCore
  → presence meter: 8th-order high-pass at the bottom of the detection range
  → noise gate with hysteresis, adapted to the room's noise floor
  → YIN: FFT cross-correlation (Accelerate) → CMNDF → parabolic interpolation
  → octave continuity (no jump while a string dies away)
  → string selection (automatic, or pinned to one string)
  → low-partial refinement (inharmonicity correction, per string)
  → smoothing → in-tune stability with hysteresis → hold
  → TunerFrame → TunerModel → SwiftUI
```

- **Detector.** The difference function is computed as `E₀ + E_τ − 2·c(τ)` with `c` obtained through the frequency domain, so one analysis costs `O(N log N)` instead of `O(W · lags)`. The search range follows the tuning and A4; pinning a string narrows it to 0.7×–1.5× of that string, which rules out octave errors by construction.
- **Inharmonicity.** Real steel strings are stiff: overtone `k` sits about `866·B·k²` cents sharp of `k·f0`, which pulls YIN's period sharp by one to four cents on a typical string (up to eight on a stiff one). Each string has a streaming band-pass (`PartialFilter`: 4th-order Butterworth low-pass at 1.6× the string, 2nd-order high-pass at 0.5×, and a notch (Q 4) at every mains frequency of the 50 and 60 Hz families inside the band except within 300 cents of the string, all in double precision) running on the continuous stream, so it has no edge transients. After YIN has found the period, `PitchDetector.refine(_:lowPassed:)` measures it again on that string's filtered window, where only the fundamental and part of the second partial remain. The difference is averaged over time (it is a property of the string) and applied to the reading. A measurement that is not clearly periodic is ignored.
- **Mains hum.** Hum inside a low string's band beats with the fundamental: the refined period oscillates at the beat frequency and hum below the fundamental pulls it flat. Averaging only cancels the oscillation when the analyses fall on different phases of the beat; at one beat per analysis it becomes a bias (a low D read 10 cents flat at the Low Power rate). The notches remove the hum instead. After every attack the filter rings, its notches longest, so the refinement waits five time constants of the slowest section (`PartialFilter.settlingSamples`) before measuring, and meanwhile keeps the correction it already knows for the string. When the correction changes, the averaged history moves with it: it is an offset of the instrument, not an observation.
- **Octave continuity.** As a note decays into noise and hum, YIN can latch onto two to four times the period (or a fraction of it). Without a new pluck — a level rise by 1.5× — a detection at such a ratio from the note being followed is folded back onto it.
- **Accuracy.** A physically informed string model (inharmonicity, pluck position, partial decay, microphone roll-off, pick and room noise, mains hum) is played through the engine for every tuning and string; the numbers, the method and the limits are in [ACCURACY.md](ACCURACY.md). Real recordings added to `Tests/TunerCoreTests/Fixtures/Recordings` become regression tests.
- **What counts as signal.** The gate judges a level, so a level of the whole room lets interference decide whether a string is heard. An amplifier that is merely switched on idles with mains hum, a computer has a fan, a desk carries footsteps — all below every string of the tuning, however badly it is tuned. The gate learned that as its noise floor and raised its threshold by the same factor, so a string was masked by interference it does not share a single frequency with: the first field test found the B and the top E immovable over an amplifier turned down low. The level therefore comes from `PresenceMeter`, an 8th-order Butterworth high-pass at the bottom of the detection range (a 50 Hz hum loses 19 dB against standard tuning's 65.9 Hz corner, the low E itself 0.1 dB), measured over the level window alone rather than over whatever part of it the tuning's analysis window happened to cover. Nothing here touches what is measured — a reading comes from the unfiltered window and its own string filter — so it can only change whether a reading is produced, never its value. Drop C reaches 52.3 Hz, where 50 Hz hum is inside the range the tuner must search and only the string filters' notches can remove it.
- **Engine parameters.** Noise gate opens at 0.004 RMS and closes at 0.0025 in a noisy room; in a quieter one it opens 4× (+12 dB) above the measured noise floor, down to 0.0006 RMS (−64 dBFS), so a soft source needs no extra input gain. The floor estimate falls at once to anything quieter, rises at most 3 dB per second while nothing is played, and stands still while a note sounds; minimum clarity 0.55; deviations beyond ±300 cents are ignored; "in tune" is ±5 cents with 2 cents of exit margin and six consecutive stable analyses; the last reading is held for 0.8 s after the signal fades.
- **Cadence.** One analysis every 25 ms (~40 Hz), at fixed positions in the stream: a chunk that spans several hops is analyzed at each of them, so the device's callback size changes how often the screen updates, never the readings, the stability count or the hold time. In Low Power Mode or under serious thermal pressure `PowerProfile` relaxes this to 45 ms. Smoothing weights are defined per 25 ms and converted to the actual interval, so the needle settles in the same time at either rate; the Low Power rate is held to the same accuracy envelope.

## Concurrency model

The package is built in Swift 6 language mode; the app with `SWIFT_STRICT_CONCURRENCY = complete`.

- `EngineAudioCapture` is an **actor**. The audio-thread tap closure touches no actor state; it copies the samples and yields them into a stream.
- `TunerProcessor` is an **actor** that owns the non-`Sendable` `TuningEngine` and runs the whole audio loop: it reads the capture stream and hands the main actor only `TunerFrame`s (newest one kept). If the UI stalls it misses frames, never audio, so the analysis window stays contiguous. Configuration changes reach it within one analysis hop.
- Each chunk carries its device sample time. A jump means audio was lost; the engine then discards its window and filter state instead of splicing two unrelated stretches of signal.
- System notifications become `AsyncStream`s through `SystemNotifications`, which registers observers synchronously and keeps their tokens in a `Mutex`; the only `nonisolated(unsafe)` left is the immutable Core Audio listener block.
- `TunerModel`, `TunerHub` and `TunerSettings` are `@MainActor @Observable`. Properties are written only when the value changes, which keeps SwiftUI redraws to a minimum.
- Session control uses a **generation counter**: every `start()` and `stop()` bumps it, and every asynchronous continuation checks that it still belongs to the current generation before acting. A permission prompt or a slow start that finishes after the user stopped is therefore ignored.
- A route or hardware-format change, or a reset of the media services, ends the stream with `CaptureFailure.configurationChanged`; the model restarts capture up to three times before reporting the failure.
- A phone call or Siri interrupts capture (`CaptureFailure.interrupted`). When the system reports that the interruption has ended with the "may resume" option, the model starts listening again by itself.

## State

`TunerModel.Status` is `idle → starting → listening`, or `failed(CaptureFailure)`. The UI maps failures to text; `CaptureFailure` carries no user-facing strings.

`TunerHub` owns one `TunerModel` per window, knows which windows are open and which was focused last, so Siri, Shortcuts, the Dock menu and menu commands act on the tuner you are looking at, never on one whose window was closed; with no window open, the Dock menu opens one before it starts listening ([ADR 0012](adr/0012-windows-and-listening-sessions.md)). iPhone and iPad run a single scene. Models are created lazily (which also makes window restoration work) and released, with their audio, when a window closes.

## Preferences

`TunerSettings` persists to `UserDefaults`. The keys `A4`, `tuningPresetID` and `preferredInputUID` are the ones used by 1.x, so calibration and tuning survive the upgrade. A4 is clamped to 415–466 Hz.

## Siri and Shortcuts

App Intents reach the running tuner through `AppDependencyManager` (`@Dependency var hub: TunerHub`). Available actions: start tuning (opens the app, because a microphone needs the foreground), stop tuning, set tuning, set reference pitch, pick a string, choose an input.

`StartTuningIntent` lives in `Shared/` and is compiled into the Controls extension as well. The extension only describes the control; because the intent opens the app, the system performs it in the app process, where the hub exists. It uses literal string keys, present in both string catalogs (a policy test keeps them identical).

## Build configuration

Build settings live in `Config/*.xcconfig`, not in the project file: `Base` (platforms, Swift, security), `Debug`, `Release`, `App`, `Controls`, `UITests`. The app icon is an Icon Composer document (`App/Resources/AppIcon.icon`), rendered by the system in the default, dark, clear and tinted appearances. Signing material and sandbox entitlements are described in [CODE_SIGNING.md](CODE_SIGNING.md).

## Testing

`swift test --package-path Packages/ChitarraTuneKit` runs the Swift Testing suites for `TunerCore` (notes, tunings, correlator, detector, engine, realistic signals, recorded corpus), `TunerFeature` (model and settings, using test doubles) and the repository policies (privacy, entitlements, workflows, localization, color contrast, App Store metadata, architecture decisions).

The UI tests (`ChitarraTuneUITests`) drive the app in demo mode on iPhone, iPad and Mac, and run Xcode's accessibility audit on every screen in light and dark appearance, landscape and the largest text size. CI runs all of them; the full DSP matrix runs in an optimized build. What only real hardware can show is in the [device test plan](DEVICE_TEST_PLAN.md).
