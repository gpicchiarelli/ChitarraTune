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
- **Cost.** The whole engine, six string filters included, uses 0.7 % of one core in an optimized build (`RealTimeBudgetTests`).

The design and its rules are in [ARCHITECTURE.md](ARCHITECTURE.md#signal-path) and [ADR 0008](adr/0008-measurement-integrity.md).

## How accuracy is protected

- **Golden readings.** Every frame the engine produces for the 132 reference signals is frozen. A change must reproduce them: discrete values exactly, frequencies and cents within 0.02 cent. A change that is meant to alter a measurement regenerates them and explains why in its commit.
- **An envelope no regeneration can loosen:** the right string on every settled reading, a median error of at most 2 cents per note and 0.5 cent overall, at both analysis rates.
- **Invariance tests:** callback size, copying the engine, hum at 50 and 60 Hz, filter ringing after an attack, soft sources in quiet rooms.

## Limits

- **Modeled, not yet field-proven.** The string model covers inharmonicity, pluck position, microphone roll-off, pick and room noise and hum, but only real instruments prove a tuner. Recordings of real guitars, with the reading of a reference tuner, become regression tests: see [the corpus](../Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/Recordings/README.md).
- **One string at a time.** Chords are not analyzed.
- **Very soft, bright plucks** (close to the bridge) are the hardest case: about 1 cent typical, with occasional readings several cents off before the note settles.
- **Update rate.** On a device that delivers long audio buffers, the needle updates less often; readings are unaffected.
