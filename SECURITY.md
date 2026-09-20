# Security policy

## Reporting a vulnerability

Report security problems **privately**, not in a public issue:

**[Report a vulnerability](https://github.com/gpicchiarelli/ChitarraTune/security/advisories/new)** (GitHub private vulnerability reporting)

Include what you found, how to reproduce it, the version affected (*About ▸ Copy Diagnostics* shows it) and, if you have one, a proposed fix.

If GitHub is unreachable, or the report is about this repository's own pipeline, write to [gpicchiarelli@gmail.com](mailto:gpicchiarelli@gmail.com?subject=ChitarraTune%20security) and say only that you have a security report; the details can follow on the advisory.

## What to expect

ChitarraTune is maintained by one person, so these are the times one person can keep:

| | |
| :-- | :-- |
| Acknowledgement | Within 7 days |
| An assessment, and a fix or a plan with dates | Within 30 days |
| Disclosure | The advisory is published with the fix, crediting you unless you prefer otherwise |

Please give a fix that time before disclosing. If a deadline passes without an answer, say so in the advisory: silence is a failure of this policy, not a reason to stay quiet indefinitely.

## Safe harbour

Research done in good faith under this policy is welcome, and will not be met with legal action or a complaint to your provider. Good faith means: only your own devices and your own copy of the app, no access to anyone else's data, no service disruption, no social engineering of the maintainer or of Apple, and a private report before publication.

## Supported versions

Security fixes go into the latest release and into `main`.

## Security model

There is very little to attack, by design. Every property below is written down as a [binding decision](docs/adr/README.md), and something in the test suite fails when it stops being true.

| Property | How it holds |
| :-- | :-- |
| Audio never leaves the device | No networking code, and no network entitlement: `ENABLE_INCOMING_NETWORK_CONNECTIONS = NO`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO` ([ADR 0003](docs/adr/0003-least-privilege-and-platform-security.md)). |
| Audio is never recorded | Samples live only in the engine's sliding analysis window and are overwritten as new audio arrives. No build, Debug included, can write, export or share audio; a test scans every source file for it ([ADR 0002](docs/adr/0002-audio-never-leaves-memory.md)). |
| Least privilege | App Sandbox with a single resource entitlement, audio input; the Controls extension has none. Test hooks exist only in Debug builds ([ADR 0006](docs/adr/0006-test-hooks-only-in-debug-builds.md)). |
| Private diagnostics | The log never makes error descriptions, device names or audio public ([ADR 0004](docs/adr/0004-logging-and-diagnostics.md)). |
| Hardened process | Hardened Runtime, Xcode Enhanced Security (hardened heap, read-only dyld data, platform restrictions) and pointer authentication (`arm64e`) on everything that ships. |
| Small supply chain | No third-party dependencies. GitHub Actions pinned to full commit SHAs and runners to explicit images; Dependabot keeps them current ([ADR 0010](docs/adr/0010-supply-chain-and-repository-security.md)). |
| Verifiable releases | Releases are built only from `main`, checked as notarization and App Review would, signed, notarized and stapled; the disk image ships with a SHA-256 checksum and a build-provenance attestation ([ADR 0013](docs/adr/0013-release-readiness.md), [ADR 0014](docs/adr/0014-disk-image-distribution.md)). |

## In scope

- Memory-safety bugs, crashes triggered by external input, sandbox or entitlement escapes.
- Anything that records, stores or transmits audio, or reaches the network.
- Weaknesses in the build and release pipeline: workflows, signing, notarization, the disk image.

## Out of scope

- Issues that need an already compromised device, a jailbreak or root access.
- Findings in Apple's software (macOS, iOS, Xcode) that this project does not cause.
- Missing hardening with no demonstrable impact.
