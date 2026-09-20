# ADR 0001: Record architecture decisions

Status: Accepted (2026-09-19)

## Context

ChitarraTune is a measuring instrument that handles microphone audio and ships to the App Store. Decisions about privacy, security, measurement and process used to live in commit messages, code comments and the memory of whoever made them, where a later change can quietly undo them.

## Decision

1. Every decision that constrains more than one file, or that a reasonable contributor might otherwise undo, MUST be recorded here as an ADR.
2. An ADR has exactly these sections, in this order: *Context*, *Decision*, *Consequences*, *Enforcement*. Its status line reads `Accepted (YYYY-MM-DD)` or `Superseded by ADR NNNN`.
3. Rules are numbered and written with MUST / MUST NOT. A rule that cannot be checked by a machine says who checks it and when.
4. *Enforcement* names at least one existing test, script or workflow by its path. An ADR without enforcement is an intention, not a decision, and is not accepted.
5. A change that contradicts an ADR MUST supersede it with a new ADR in the same commit. ADRs are never edited to say something else; only their status line changes.
6. Files are numbered consecutively (`NNNN-kebab-title.md`) and listed in [README.md](README.md).

## Consequences

- Decisions are reviewable in one place and survive the people who made them.
- Changing a rule costs a written justification; that friction is intended.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/ADRPolicyTests.swift` checks numbering, the index, the sections, the status line and that every path named under *Enforcement* exists.
