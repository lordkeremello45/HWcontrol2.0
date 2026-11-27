# HWcontrol2.0 Wiki

HWcontrol2.0 is a Beta desktop application for hardware monitoring, diagnostics, and capability-gated control. This wiki documents implementation details and engineering procedures.

## Start here

- **[All-in-One Kurulum, Tanıtım ve Başlangıç Rehberi](../ALL-IN-ONE-KURULUM-TANITIM-BASLANGIC-REHBERI.md)** — the end-user guide, limited to product introduction, installation and first steps.
- [Wiki Index](Wiki-Index.md) — navigation to focused subsystem and platform documents.
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

## Engineering evidence

- [Physical hardware validation matrix](../HARDWARE-VALIDATION-MATRIX.md)
- [Engineering completion roadmap](Engineering-Completion-Roadmap.md)
- [Final release runbook](../FINAL-RELEASE-RUNBOOK.md)

A CI build does not prove physical sensor accuracy, fan response, safe recovery, or full installation lifecycle. Publisher signing is separate from checksums and artifact attestations.

## Project links

- [GitHub source](https://github.com/lordkeremello45/HWcontrol2.0)
- [GitHub Releases](https://github.com/lordkeremello45/HWcontrol2.0/releases)
- [Project website](https://lordkeremello45.github.io/HWcontrol2.0/)
