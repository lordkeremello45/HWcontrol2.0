# HWcontrol2.0 Wiki

HWcontrol2.0 is a Beta desktop application for hardware monitoring, diagnostics, and capability-gated control. This wiki documents the repository's actual implementation and explicitly distinguishes implemented, partial, unavailable, and unverified behavior.

## Start here

- **[Project Master Documentation](../PROJECT-MASTER.md)** — canonical overview of architecture, current capabilities, platform boundaries, security, validation, packaging, and release policy.
- [Wiki Index](Wiki-Index.md) — complete navigation to focused subsystem and platform documents.
- [Getting Started](Getting-Started.md) — installation and source-build guides.
- [Features](Features.md) — feature specifications and current limits.
- [Architecture](Architecture.md) — runtime and hardware architecture.
- [Development](Development.md) — contributor and CI guidance.
- [Testing](Testing.md) — unit, smoke, and platform validation.
- [Troubleshooting](Troubleshooting.md) — diagnostic guides.

## Project at a glance

| Area | Current implementation |
|---|---|
| Desktop UI | Flutter / Dart |
| Authenticated local bridge | Go |
| Hardware collection and supported control | Go bridge with OS-specific adapters |
| Native helpers | C++ / CMake AI and audio components |
| Targets | Windows 10/11 x64, Debian/Ubuntu-family Linux x64, macOS 14+ Apple Silicon |
| Release channel | Beta |

The Go bridge is the active hardware boundary. C++ helpers are not a shared hardware-control engine. Hardware support varies by device, driver, operating system, and permissions.

## Evidence and trust

- [Current implementation and engineering gates](../PROJECT-MASTER.md)
- [Physical hardware validation matrix](../HARDWARE-VALIDATION-MATRIX.md)
- [Engineering completion roadmap](Engineering-Completion-Roadmap.md)
- [Final release runbook](../FINAL-RELEASE-RUNBOOK.md)

A CI build does not prove physical sensor accuracy, fan response, safe recovery, or full installation lifecycle. Publisher signing is separate from checksums and artifact attestations.

## Project links

- [GitHub source](https://github.com/lordkeremello45/HWcontrol2.0)
- [GitHub Releases](https://github.com/lordkeremello45/HWcontrol2.0/releases)
- [Project website](https://lordkeremello45.github.io/HWcontrol2.0/)
