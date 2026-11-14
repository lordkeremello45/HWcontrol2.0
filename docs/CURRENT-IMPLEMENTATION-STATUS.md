# Current Implementation Status

> **Status snapshot: 14 November 2026.** HWcontrol2.0 is Beta and under active development. This document describes the repository implementation, not a promise that every feature works on every machine. Source presence, CI success, package creation, and physical-hardware validation are different evidence levels.

## Product and runtime architecture

The current hardware-monitoring runtime is:

```text
Flutter / Dart desktop dashboard
        |
        | HMAC-authenticated local IPC
        v
Go bridge (hardware boundary)
  - request authentication, validation and replay protection
  - telemetry collectors and hardware identity
  - health, diagnostics, history and Game Mode services
  - capability-gated platform control adapters
        |
        v
Windows / Linux / macOS APIs, drivers and device interfaces
```

Separate native components are not the current hardware-control engine:

- `ai_core/`: C++/CMake local AI analysis and related helper code.
- `audio_core/`: C++/CMake audio-device and DSP functionality.
- `hw_game_core/`: C++/CMake graphics-backend selection and render-graph work; not the HWcontrol dashboard renderer or a released game engine.
- `security/spark-core/` and `security/rust-support/`: security-policy and FFI support components. The SPARK C ABI is not yet invoked by every production hardware-control command.
- `lib/hardware-identification/`: supporting hardware identity component; the Go bridge remains the current runtime hardware boundary.

## Implemented in source

| Area | Current implementation | Evidence boundary |
|---|---|---|
| Dashboard and bridge | Flutter/Dart UI, authenticated local Go bridge, typed telemetry and capability status | Does not imply every platform feature is available |
| Hardware monitoring | CPU, memory, storage, GPU and fan telemetry through available OS/driver interfaces | Missing sensors remain unavailable; values vary by device |
| Hardware identity | System, board, BIOS, CPU and GPU identity with platform-specific collectors and cached discovery | Informational only; not proof of control support |
| Fan curves and automation | Persisted point-based curves, temperature rules, smoothing and thermal emergency policy | Actual writes only on validated writable channels |
| Fan control | Linux hwmon PWM channel path with RPM feedback, manual-mode precondition and readback checks | Windows/macOS writes unavailable; Linux hardware coverage remains device-specific |
| Game Mode | Allow-listed process detection, session state and local per-game profile assignment | No clock/voltage/power-limit tuning or process-priority changes |
| Telemetry history | Bounded local history, graphs, CSV export and diagnostic context | Not a cloud telemetry service |
| Battery panel | Read-only design/full-charge capacity, estimated capacity ratio and optional cycle/charge state | Source implemented; physical laptop validation pending |
| Healthy Core | Deterministic CPU/GPU thermal-condition indicator and contextual RAM utilization | Not silicon-wear measurement or remaining-life prediction |
| Local AI | Optional Gemma 3 1B GGUF / llama.cpp analysis path with verified model download and local inference | Optional model; AI is advisory and cannot authorize hardware writes |
| Liquid cooling | Optional external liquidctl status parsing | Read-only telemetry; no pump/fan control or leak detection |
| Diagnostics | Local structured diagnostics, redaction and export paths | Review exported data before sharing |
| CPU benchmark | Bounded CPU-only benchmark using worker execution and repeated samples | Not a GPU benchmark or stress test |
| Extension contract | Validated metadata/capability manifest | No arbitrary native plugin loading |
| Piper speech | Optional local Piper executable/model integration | User supplies binaries/models; not bundled |
| Audio Controller Studio | Audio profile controls and microphone-processing integration with native audio host | System loopback, virtual devices and per-app routing remain unavailable |
| Aim Trainer | Offline local practice screen with session statistics | No game integration, input injection or hardware-control role |

## Partial, experimental or not yet verified

- Physical sensor, fan-control, battery and cooling behavior has not been exhaustively validated across the target hardware matrix.
- Windows and macOS fan writes are unavailable; Linux PWM support is limited to detected channels that pass all safety preconditions.
- Liquid cooling remains read-only and depends on a separately installed, supported `liquidctl` CLI.
- Operating-system power-mode support is platform-specific: Windows 11 has AC/DC configured-mode adapters; Linux has a power-profiles-daemon system-profile adapter. Windows 10 and macOS automatic switching are unavailable. Adapter implementation is present, but platform runtime validation remains pending. Quiet/Balanced/Performance application presets must not be interpreted as universal OS power-mode changes.
- The C++ Game Core is an early backend/render-graph component, not a complete Direct3D 12 + Vulkan game engine or a released 2D/3D runtime.
- The BSOD Shield source contains a heartbeat/watchdog primitive; do not describe it as a complete BSOD prevention or recovery product.
- Ada/SPARK formal policy exists, but full production-path linking and end-to-end invocation from every relevant Go hardware command are not verified.
- Production signing, notarization, physical installation lifecycle and release readiness must be checked against the relevant workflow run and release artifacts each time.

## Platform support boundaries

| Platform | Project target | Important current limitation |
|---|---|---|
| Windows 10/11 x64 | Beta target | Fan writes unavailable; OS power-mode adapter requires Windows 11 APIs and is unavailable on Windows 10 |
| Debian/Ubuntu-family Linux x64 | Beta target | Fan writes only for validated hwmon PWM channels; OS power profiles require power-profiles-daemon and policy permission |
| macOS 14+ Apple Silicon | Beta target | Fan writes unavailable; Intel macOS is not a current package target |

A target platform is not a claim that every device, sensor, installer, or control feature has been validated there. See [Physical Hardware Validation Matrix](HARDWARE-VALIDATION-MATRIX.md).

## Security and privacy boundaries

- The Go bridge is the active request and hardware-control boundary.
- HMAC authentication and replay checks do not replace capability checks, authorization, input validation or OS permissions.
- AI output, extension metadata and hardware identity data are untrusted inputs; none can independently authorize privileged operations.
- Local telemetry history and diagnostics are stored locally; no automatic telemetry upload is implied.
- The root desktop project is GPL-3.0. The `website/` source is separately AGPL-3.0-only. See [license details](https://github.com/lordkeremello45/HWcontrol2.0/wiki/License).

## Release and validation policy

Before describing a release as ready, inspect the current GitHub Actions results and release assets. Verify source build, tests, package creation, install/launch/uninstall smoke tests, artifact integrity, signing/notarization and physical hardware evidence independently. A green CI run does not prove physical hardware compatibility.

Useful references:

- [README](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/README.md)
- [Hardware validation matrix](HARDWARE-VALIDATION-MATRIX.md)
- [Product readiness checklist](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/docs/PRODUCT-READINESS-CHECKLIST.md)
- [Final release runbook](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/docs/FINAL-RELEASE-RUNBOOK.md)
- [Wiki home](https://github.com/lordkeremello45/HWcontrol2.0/wiki/Home)
