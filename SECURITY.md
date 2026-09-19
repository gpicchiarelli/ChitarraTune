# Security Policy

## Reporting a vulnerability

Please report security problems **privately**, not in a public issue:

**[Report a vulnerability](https://github.com/gpicchiarelli/ChitarraTune/security/advisories/new)** (GitHub private vulnerability reporting)

Include what you found, how to reproduce it, the affected version (About → Copy info) and, if you have one, a proposed fix. This is a one-person project: reports are handled on a best-effort basis, and you will get an acknowledgement and a status update as soon as they can be given.

## Supported versions

Only the latest release and the `main` branch receive security fixes.

## Security model

ChitarraTune is designed so that there is very little to attack. Each property below is a binding [architecture decision](docs/adr/README.md) enforced by tests:

| Property | How it is enforced |
| --- | --- |
| Audio never leaves the device | No networking code, and the sandbox network entitlements are off (`ENABLE_INCOMING_NETWORK_CONNECTIONS = NO`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO`). |
| Audio is never recorded | Samples live only in the engine's sliding analysis window and are overwritten as new audio arrives. No build, Debug included, can write, export or share audio ([ADR 0002](docs/adr/0002-audio-never-leaves-memory.md)); a test scans the code for it. |
| Minimal privileges | macOS App Sandbox with a single resource entitlement: audio input ([ADR 0003](docs/adr/0003-least-privilege-and-platform-security.md)). Test hooks exist only in Debug builds ([ADR 0006](docs/adr/0006-test-hooks-only-in-debug-builds.md)). |
| Private diagnostics | The log never publishes error descriptions, device names or audio ([ADR 0004](docs/adr/0004-logging-and-diagnostics.md)). |
| Hardened process | Hardened Runtime and Xcode Enhanced Security (hardened heap, dyld read-only, platform restrictions). |
| Small supply chain | No third-party dependencies. GitHub Actions are pinned to full commit SHAs and kept current by Dependabot. |
| Verifiable releases | The release workflow signs, notarizes and checksums the archive, and publishes a build-provenance attestation for it. It refuses to publish from a commit that is not on `main`. |

## In scope

- Memory-safety bugs, crashes triggered by external input, or sandbox and entitlement escapes
- Anything that records, stores or transmits audio, or that reaches the network
- Weaknesses in the build and release pipeline (`.github/workflows`, signing, notarization)

## Out of scope

- Issues that require an already compromised device, jailbreak or root access
- Findings in third-party software (macOS, iOS, Xcode) that are not caused by this project
- Missing hardening that has no demonstrable impact
