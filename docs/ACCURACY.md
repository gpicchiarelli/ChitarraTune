# Accuracy

How precise ChitarraTune is, how that is measured, and where the limits are. Every number on this page comes from a test that runs on every push; the test is named next to it.

## What the tuner promises

| | |
| :-- | :-- |
| In-tune window | ±5 cents, confirmed after six consecutive stable analyses; it stays green until the string drifts beyond ±7 cents |
| Analysis rate | Every 25 ms (every 45 ms in Low Power Mode or under thermal pressure) |
| Reference pitch | A4 from 415 to 466 Hz |
| Capture window | ±300 cents around each string; further away nothing is shown |
| Level | Opens 12 dB above the room's noise floor, between −64 and −48 dBFS |

## Measured accuracy

Errors are the median of the settled readings of each note, against the pitch that was actually played.

**Reference signals** (`GoldenReadingsTests`): every string of every tuning, in tune and detuned, at 44.1, 48 and 96 kHz, as harmonic tones and as modeled plucked steel strings with room noise and mains hum. 132 notes.

| Analysis rate | Median | Mean | 90th percentile | Worst note |
| :-- | --: | --: | --: | --: |
| Normal (25 ms) | 0.16 ¢ | 0.18 ¢ | 0.38 ¢ | 0.49 ¢ |
| Low Power (45 ms) | 0.09 ¢ | 0.16 ¢ | 0.40 ¢ | 0.59 ¢ |

**Realistic conditions** (`RealisticSignalTests`): every string of every tuning, modeled as a real instrument in a real room. *Typical* is the median of the notes; *worst* is the single worst settled reading.

| Scenario | Typical | Worst reading |
| :-- | --: | --: |
| Pickup into an audio interface, 48 kHz | 0.34 ¢ | 1.2 ¢ |
| Acoustic guitar in front of a phone | 0.31 ¢ | 1.3 ¢ |
| Phone in a noisy room | 0.35 ¢ | 3.5 ¢ |
| Very stiff strings, plucked over the sound hole | 0.85 ¢ | 3.8 ¢ |
| Quiet pluck close to the bridge | 1.1 ¢ | 8.4 ¢ |

**Mains hum** at twice the everyday level, 50 or 60 Hz, on the low strings of every tuning, at both analysis rates: typical 0.5–0.6 ¢, worst note 1.6 ¢.

## How it gets there

- **YIN on the whole signal** finds the period and the string. It is computed through an FFT, about 23 µs per analysis on an Apple M4.
- **A second measurement on the string's own band.** Steel strings are slightly inharmonic: their overtones sit sharp of exact multiples, which pulls a period detector one to eight cents sharp. Each string has a streaming band-pass that keeps only the fundamental and part of the second partial. The period measured there gives a correction, averaged over time.
- **Mains hum is removed, not averaged.** Notches at 50, 60 Hz and their harmonics inside each string's band stop the hum from beating with a low string's fundamental.
- **Time, not callbacks.** The engine analyzes at fixed positions in the stream, whatever size of buffer the device delivers, and smooths over time rather than per analysis. Readings are identical whether audio arrives in 17-sample or 8 192-sample chunks.
- **Where it stops being this good.** The figures above come from signals built the way the engine expects. `FalsificationTests` builds signals that break each of the model's assumptions in turn, and holds the reading to the in-tune window (±5 cents) rather than to the medians above — the claim that matters is that the tuner tells the truth about whether a string is in tune, not that it reproduces a generator. Partials placed off any stiffness law (±8 cents each, which no single *B* can produce) cost 0.7–1.1 cents; a fundamental that dies before its second partial, 0.3; two polarisations beating four cents apart, 0.7 from their midpoint; a low string whose fundamental the microphone has removed entirely, 0.6. The one that found a limit is a body resonance: a tone that is not the string's, a few hertz from its fundamental and inside the band the refinement measures in. Up to two fifths of the fundamental's amplitude the reading stays inside the window; past that it reaches **six cents**, because at that point the interferer is a second note as loud as the string and no period estimator separates the two. The string chosen stays right throughout.
- **Cost.** The whole engine, six string filters included, stays under **3 %** of one core in an optimized build, which is the ceiling `RealTimeBudgetTests` enforces. Measurements sit far below it — 0.6 % on an M-series Mac, 1.6 % on a shared CI runner — but a measurement is a property of the machine and the toolchain, so the ceiling is what is promised.

The design and its rules are in [ARCHITECTURE.md](ARCHITECTURE.md#signal-path) and [ADR 0008](adr/0008-measurement-integrity.md).

## How accuracy is protected

- **Golden readings.** Every frame the engine produces for the 132 reference signals is frozen. A change must reproduce them: discrete values exactly, frequencies and cents within 0.02 cent. A change that is meant to alter a measurement regenerates them and explains why in its commit.
- **An envelope no regeneration can loosen:** the right string on every settled reading, a median error of at most 2 cents per note and 0.5 cent overall, at both analysis rates.
- **Invariance tests:** callback size, copying the engine, hum at 50 and 60 Hz, filter ringing after an attack, soft sources in quiet rooms, an idling amplifier, and a non-finite sample that must not leave the measurement biased.

## Limits

- **Modeled, not yet field-proven.** The string model covers inharmonicity, pluck position, microphone roll-off, pick and room noise and hum, but only real instruments prove a tuner, and so far that means one electric guitar, one amplifier and one room. Recordings of real guitars, with the reading of a reference tuner, become regression tests: see [the corpus](../Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md).
- **One string at a time.** Chords are not analyzed.
- **Very soft, bright plucks** (close to the bridge) are the hardest case: about 1 cent typical, with occasional readings several cents off before the note settles.
- **A string barely above an amplifier's hum.** The gate judges the level of the detection band, not of the room, so an amplifier idling with mains hum no longer masks the strings above it (`QuietInputTests`). The measurement at that ratio is still the weakest case: a string only about 12 dB above the hum gives readings spread over about 9 cents, with a median a few cents out — measured 3.5 flat on the low E and 3.3 sharp on the G. It is the hum and not merely a poor ratio: the same interference power at 60 Hz instead of 50 moves the low E's error to 1.6 flat, so it tracks the mains frequency. Ten times that level over the same amplifier is measured as accurately as in silence: under 0.3 cent.

  Both strings are understood. The low E reads flat because the mains third harmonic (150 Hz on a 50 Hz supply) sits just above its notch band and only 6 dB down, beside the second partial the refinement keeps part of. The G reads sharp because the mains fundamental sits *below* its notch band, where nothing notches it and the string filter's 2nd-order high-pass only takes 12 dB off it.

  **Three fixes were measured and all three rejected.** Each one trades the tuning everybody does for the weakest case, which is the wrong way round ([ADR 0008](adr/0008-measurement-integrity.md) rules 2 and 7):

  | Attempt | What it fixes | What it costs |
  | :-- | :-- | :-- |
  | Notch band up to the second partial (1.76× → 2.0× the string) | Low E 3.5 → 1.5 ¢ at 50 Hz, 1.6 → 1.1 at 60 Hz | **Every** envelope statistic worse: median 0.164 → 0.192 ¢, worst 0.491 → 0.572; Low Power 0.087 → 0.142 and 0.593 → 0.717. The extra notches take part of the band the refinement measures. |
  | Notch band down to 0.2× the string, catching mains below it | G 3.3 → 0.3 ¢, and the Low Power envelope improves on all four statistics | Settling after every pluck doubles on four of the six strings (D, G, B: 42–64 ms → 127 ms), because a 50 Hz notch rings longer than those strings' own filters; standard-rate median 0.164 → 0.201 ¢. |
  | 4th-order high-pass instead of 2nd | G 3.3 → 0.1 ¢ | Low E 3.5 → 4.2 ¢ worse, and all four standard-rate statistics worse: median 0.164 → 0.223 ¢, worst 0.491 → 0.565. |

  Removing this interference properly means tracking the hum and subtracting it, which leaves the passband alone instead of cutting holes in it. That is a real piece of work rather than a parameter change, and it is not scheduled.
- **Update rate.** On a device that delivers long audio buffers, the needle updates less often; readings are unaffected.
