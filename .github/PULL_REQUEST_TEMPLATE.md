## Summary · Riepilogo

<!-- What changes, and why? · Cosa cambia e perché? -->

## Type · Tipo

- [ ] Fix
- [ ] Feature
- [ ] Refactor / cleanup
- [ ] Docs / CI

## Verification · Verifica

- [ ] `Scripts/verify.sh` passes (lint, no warnings, tests, coverage floors)
- [ ] A bug fix comes with a test that fails without it
- [ ] The app builds for macOS and for the iOS Simulator
- [ ] Tried with a real instrument (if audio, the engine or permissions are involved)
- [ ] No measurement changed, or the golden readings were regenerated and the commit explains why the new numbers are more correct

## Invariants · Invarianti

- [ ] No network access, no audio recording or persistence
- [ ] No new entitlement, permission or third-party dependency (or it is explained above)
- [ ] User-facing text is in the string catalogs, in English and Italian
- [ ] Nothing contradicts an [architecture decision](../docs/adr/README.md), or the ADR is superseded in this change

## Screenshots · Schermate

<!-- For UI changes, before and after. · Per le modifiche all'interfaccia, prima e dopo. -->
