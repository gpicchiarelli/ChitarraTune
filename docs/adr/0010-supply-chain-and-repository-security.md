# ADR 0010: Supply chain and repository security

Status: Accepted (2026-09-19)

## Context

The code that builds, signs and notarises the app runs in GitHub Actions. A compromised action, an unpinned container or a leaked secret would reach every user.

## Decision

1. Every third-party action MUST be pinned to a full commit SHA; every container image to an explicit version.
2. Workflows MUST declare least-privilege permissions; only the release workflow may write contents. Every checkout MUST drop its credentials; every job MUST have a timeout.
3. Untrusted event data MUST NOT reach a shell.
4. Dependabot keeps pinned actions current; CodeQL, secret scanning with push protection and private vulnerability reporting stay enabled.
5. No secrets, certificates, provisioning profiles or keys are committed. Signing material lives only in GitHub encrypted secrets and the maintainers' keychains.
6. Releases are notarised and carry a SHA-256 checksum and a build-provenance attestation.

## Consequences

- Updating a tool is a reviewed Dependabot change, never a floating tag.

## Enforcement

- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/WorkflowPolicyTests.swift` (pins, permissions, timeouts, credentials, script injection, Dependabot).
- `Packages/ChitarraTuneKit/Tests/RepositoryPolicyTests/SecurityPolicyTests.swift` (no secrets or signing material).
- `.github/workflows/release.yml`, `SECURITY.md`.
