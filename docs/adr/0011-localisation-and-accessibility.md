# ADR 0011: Localisation and accessibility

Status: Accepted (2026-09-19)

## Context

A tuner is used with both hands on a guitar, often without looking at the screen, by musicians of every ability, in English and Italian.

## Decision

1. English and Italian are the only languages; every string MUST exist, translated, in both, with matching placeholders.
2. Note names follow the user's convention (solfège for fixed-do languages) and VoiceOver MUST speak accidentals as words.
3. Text MUST reach a 4.5:1 contrast ratio (7:1 with Increase Contrast); the in-tune state MUST NOT be conveyed by colour alone.
4. Every control MUST have a label; Xcode's accessibility audit MUST pass on iPhone, iPad and Mac.
5. Layouts MUST work at the largest accessibility text size and with Reduce Motion.

## Consequences

- A new string or colour is a change to two catalogs and to the contrast tests.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/LocalizationTests.swift`, `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ColorContrastTests.swift`.
- `ChitarraTuneUITests/ChitarraTuneUITests.swift` (accessibility audit) and `docs/ACCESSIBILITY.md`.
