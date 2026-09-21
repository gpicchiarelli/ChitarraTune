# ADR 0008: Measurement integrity

Status: Accepted (2026-09-19)

## Context

ChitarraTune is a measuring instrument. A refactor that shifts readings by a cent, a device that delivers audio in larger blocks, or a CPU that rounds differently must never change what the user is told without anyone noticing.

## Decision

1. Every frame of 132 reference signals is frozen in `golden-readings.txt`. A change MUST reproduce it: discrete values exactly, continuous values within 0.02 cent (CPU rounding only).
2. An accuracy envelope that no regeneration can loosen MUST hold: the right string on every settled reading, per-note median error ≤ 2 cents, overall median ≤ 0.5 cent.
3. Regenerating the golden readings MUST be justified in the commit message, field by field, with the accuracy statistics before and after.
4. Readings MUST NOT depend on how the device slices audio: the engine analyzes at fixed positions of the stream (every hop), whatever the callback size.
5. DSP state MUST be deterministic and value-typed: the string filters run in double precision, sample by sample; copying the engine copies its state.
6. Stability ("in tune") is counted in real analyses. A slower analysis rate (Low Power Mode) takes longer to confirm, never less evidence. Smoothing is defined in time, not per analysis, and the Low Power rate MUST meet the same accuracy envelope.
7. Tolerances, thresholds and documented engine numbers MUST NOT be loosened to make a test pass; the documents quoting them are tested against the code.
8. Real recordings with a reference reading are the ground truth for real hardware (ADR 0002 rule 6).
9. The engine MUST stay within 3 % of real time in an optimized build. The cost is the **fastest** of several passes over the same audio, with the callbacks cut before the clock starts: a shared CI runner preempts the process at moments nobody controls, and preemption only ever adds time, so the fastest pass is the closest estimate of what the engine itself costs. A ceiling compared against a single noisy pass tests the runner, not the engine.
10. Interference the instrument can remove MUST be removed rather than averaged: mains hum (50 and 60 Hz families) is notched out of the refinement band, and the refinement never measures the string filter's own ringing after an attack. Averaging a periodic error only works by luck of phase.
11. Whether a string is heard MUST NOT be decided by energy at frequencies where no string of the tuning could be. The noise gate judges the level of the detection band (`PresenceMeter`), not of the room, so an amplifier's idle hum cannot raise the floor that masks a string it does not share a frequency with. That band is a property of the tuning alone: the level window MUST NOT change size with the analysis window.

## Consequences

- Measurement changes are rare, explicit and reviewable.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/GoldenReadingsTests.swift` and `Packages/ChitarraTuneKit/Tests/TunerCoreTests/Fixtures/golden-readings.txt`.
- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/ChunkingTests.swift` (chunking invariance, value semantics, real-time budget).
- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/FalsificationTests.swift` (signals that break each assumption `StringModel` makes, held to the in-tune window rather than to the medians a generator produces).
- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/RealisticSignalTests.swift` (mains hum at 50 and 60 Hz at both analysis rates; no ringing measured after an attack) and `Packages/ChitarraTuneKit/Tests/TunerCoreTests/GoldenReadingsTests.swift` (Low Power envelope).
- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/PresenceMeterTests.swift` and `Packages/ChitarraTuneKit/Tests/TunerCoreTests/QuietInputTests.swift` (the gate's band, and an idling amplifier that must not mask the strings above it).
- `Packages/ChitarraTuneKit/Tests/TunerCoreTests/PartialFilterTests.swift`, `Packages/ChitarraTuneKit/Tests/TunerCoreTests/RecordingCorpusTests.swift`, `Packages/ChitarraTuneKit/Tests/TunerCoreTests/SpecConformanceTests.swift`.
- `.github/workflows/ci.yml` (the DSP accuracy job runs the optimized build).
