# ADR 0003: Least privilege and platform security

Status: Accepted (2026-09-19)

## Context

The app needs one resource, the microphone, and nothing else: no network, no files, no contacts, no background execution. Every extra capability is attack surface and a question App Review and users are right to ask.

## Decision

1. The app and the Controls extension MUST run in the App Sandbox with Enhanced Security (hardened process, hardened heap, read-only dyld data, platform restrictions).
2. The microphone MUST be the only resource entitlement of the app; the extension MUST have none. File-access, network, personal-information, device, temporary-exception and code-signing-relaxation entitlements MUST NOT be added.
3. Incoming and outgoing network connections MUST be off; the code MUST NOT use networking APIs.
4. Shipping binaries (Release, Developer ID and App Store) MUST be built with pointer authentication (`arm64e`) and verified with `lipo`.
5. The package MUST have no third-party dependencies.
6. No background modes. Listening stops when the app leaves the foreground on iOS and when the last window closes on the Mac.
7. Convenience never justifies weakening 1–6. A development need that conflicts with them (for example a signing team that cannot grant Enhanced Security) is solved outside the repository or by superseding this ADR.

## Consequences

- A personal (free) development team cannot sign the iOS app, because it cannot grant Enhanced Security; device testing needs a paid Apple Developer Program team.
- Features that need files or the network (export, sync, analytics) are excluded unless this ADR is superseded.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (sandbox, entitlements, network settings, forbidden APIs, background modes, no dependencies).
- `.github/workflows/ci.yml` (arm64e check on shipping builds) and `.github/workflows/release.yml` (arm64e, hardened runtime and entitlements checked before notarisation).
