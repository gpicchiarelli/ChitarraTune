# ADR 0013: Release readiness on every push

Status: Accepted (2026-09-19)

## Context

Notarization and App Review are pass/fail gates that Apple runs on release day. A debugging entitlement left in, a missing architecture, a framework linked from outside the system or an unexpected entitlement is found there, days late, by someone else. Everything they check about the bundle can be checked on every push without a certificate.

## Decision

1. Every push MUST build the Mac app exactly as a release does (Release configuration, `arm64e` with `arm64` and no Intel slice, warnings as errors) and check it with `Scripts/release-check.sh`: bundle identifiers, versions, minimum system, category, export compliance, purpose strings in English and Italian, privacy manifest, icon, architectures, system-only linkage, dSYM, a strict signature, exactly the entitlements ADR 0003 allows, no `get-task-allow`, and the Hardened Runtime setting of both targets.
2. The release workflow MUST run the same script on its signed build before notarizing, adding the checks only a real certificate allows (the Hardened Runtime flag in the signature, a Developer ID or Apple Distribution authority, a secure timestamp). One script, one definition of "release-ready".
3. Release builds MUST NOT carry development entitlements, whatever identity signs them: `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` in `Config/Release.xcconfig`.
4. A Developer ID build is notarized with `notarytool`, stapled, and assessed by Gatekeeper before it is published; locally, `Scripts/release-check.sh --identity … --notarize PROFILE` does the same with a keychain profile.
5. Distribution needs a paid Apple Developer Program team: a Developer ID Application certificate outside the store, cloud-managed Apple Distribution signing for the App Store. A personal team cannot sign the app (it cannot grant Enhanced Security, ADR 0003) and is never worked around.
6. CI runs on explicitly versioned runner images, never on a moving `-latest` label.

## Consequences

- A release can fail only on what needs Apple's servers or the team's certificate.
- Adding an entitlement, a framework or an architecture change fails CI until ADR 0003 and the script agree.

## Enforcement

- `Scripts/release-check.sh`, run by the `release` job of `.github/workflows/ci.yml` and by `.github/workflows/release.yml`.
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` (both workflows run the script; the gate waits for it; runners are pinned).
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (release builds never inject development entitlements).
