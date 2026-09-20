# Architecture decision records

Binding decisions for the whole project. They are enforced by tests and CI (see each *Enforcement* section); ADR 0001 explains the rules.

Writing a new one: copy [0000-template.md](0000-template.md) to the next free number, fill in the four sections, and add its row to the table below.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-audio-never-leaves-memory.md) | Audio never leaves memory | Accepted |
| [0003](0003-least-privilege-and-platform-security.md) | Least privilege and platform security | Accepted |
| [0004](0004-logging-and-diagnostics.md) | Logging and diagnostics | Accepted |
| [0005](0005-module-boundaries.md) | Module boundaries | Accepted |
| [0006](0006-test-hooks-only-in-debug-builds.md) | Test hooks only in Debug builds | Accepted |
| [0007](0007-concurrency-model.md) | Concurrency model | Accepted |
| [0008](0008-measurement-integrity.md) | Measurement integrity | Accepted |
| [0009](0009-quality-gate-and-change-process.md) | Quality gate and change process | Accepted |
| [0010](0010-supply-chain-and-repository-security.md) | Supply chain and repository security | Accepted |
| [0011](0011-localisation-and-accessibility.md) | Localization and accessibility | Accepted |
| [0012](0012-windows-and-listening-sessions.md) | Windows and listening sessions | Accepted |
| [0013](0013-release-readiness.md) | Release readiness on every push | Accepted |
| [0014](0014-disk-image-distribution.md) | Disk image distribution outside the App Store | Accepted |
| [0015](0015-user-guide.md) | The user guide | Accepted |
| [0016](0016-build-artifacts-and-disk.md) | Build artifacts and disk | Superseded by ADR 0017 |
| [0017](0017-build-artifacts-disk-and-reuse.md) | Build artifacts, disk and reuse | Accepted |
| [0018](0018-the-tests-run-optimised.md) | The tests run optimised | Accepted |
