# HWcontrol2.0 — Project Master Documentation

> **Document role:** canonical engineering overview and navigation entry point. This document consolidates high-level project status, architecture, platform capability boundaries, engineering gates, and release policy. Detailed operational procedures, legal policies, subsystem specifications, and platform guides remain in their focused documents linked below.
>
> **Status snapshot:** 27 November 2026 · **Product channel:** Beta · **Repository:** [GitHub](https://github.com/lordkeremello45/HWcontrol2.0)
>
> Source presence, a successful compile, CI success, package creation, installation, publisher signing, and physical hardware validation are separate evidence levels. Do not treat one as proof of another.

## 1. Project definition

HWcontrol2.0 is a cross-platform desktop application for hardware monitoring, diagnostics, and capability-gated control.

### Target platforms

| Platform | Target | Current boundary |
|---|---|---|
| Windows 10/11 | x64 | Monitoring and identity are partial; fan writes are unavailable. Windows 11 power-mode adapter exists but runtime validation is pending. |
| Debian/Ubuntu-family Linux | x64 | Monitoring and discovery are partial; fan writes are limited to validated hwmon PWM channels and required permissions/manual mode. |
| macOS 14+ | Apple Silicon / arm64 | Identity support is partial; fan writes and automated OS power-mode switching are unavailable. |

A target is not a claim that every device, sensor, installer, or control feature works on that platform.

## 2. Current runtime architecture

The current hardware-control runtime is:

```text
Flutter / Dart desktop dashboard
        |
        | HMAC-authenticated local IPC
        v
Go Bridge — active hardware boundary
  - request authentication, validation and replay protection
  - telemetry collection and hardware identity
  - health, diagnostics, capability reporting and history
  - platform-specific control adapters
        |
        v
Windows / Linux / macOS APIs, drivers and device interfaces
```

Separate native components are not a shared C++ hardware-control engine:

- `ai_core/`: C++/CMake local AI analysis and helper code.
- `audio_core/`: C++/CMake audio processing and device helper code.
- `hw_game_core/`: early graphics-backend/render-graph work; not a released game engine.
- `security/spark-core/` and `security/rust-support/`: selected security-policy and FFI support. End-to-end SPARK enforcement across every production hardware command is not verified.
- `lib/hardware-identification/`: supporting identity component; the Go bridge remains the active runtime hardware boundary.

The intended future shared C++ Hardware API / Cooling HAL must not be documented as the current runtime until it is fully wired, tested, and physically validated.

Detailed specifications:
- [Application architecture](wiki/Architecture-Application.md)
- [Hardware API contract](wiki/Hardware-API-Contract.md)
- [Hardware abstraction](wiki/Architecture-Hardware-Abstraction.md)
- [Runtime hardware discovery](wiki/Architecture-Runtime-Hardware-Discovery.md)
- [Vendor adapter research matrix](wiki/Hardware-API-Vendor-Adapter-Matrix.md)
- [Data flow](wiki/Architecture-Data-Flow.md)

## 3. Implementation snapshot

### Implemented in source (not automatically hardware-verified)

| Area | Current implementation | Boundary |
|---|---|---|
| Desktop dashboard and bridge | Flutter/Dart UI, authenticated local Go bridge, typed telemetry and capability responses | Does not imply equal feature availability across OSes |
| Hardware monitoring | CPU, memory, storage, GPU, fan and host sensor data where OS/driver interfaces expose it | Missing sensors must remain unavailable, not be fabricated as zero |
| Hardware identity | System, board, BIOS, CPU and GPU identity through platform collectors | Identity does not imply sensor or actuator support |
| Fan curves | Persisted point-based curves, temperature rules, smoothing and thermal emergency policy | Writes only on validated writable channels |
| Fan control | Linux hwmon PWM path with RPM feedback, existing manual-mode precondition and command-value readback | Windows/macOS fan writes unavailable; Linux support is device/driver-specific |
| Game Mode | Allow-listed process detection, session state and local per-game profile assignment | No clock, voltage, power-limit tuning or process-priority changes |
| Telemetry history | Bounded local history, graphs, CSV export and diagnostic context | Local feature, not cloud telemetry |
| Battery panel | Read-only design/full-charge capacity and estimated capacity ratio | Physical laptop validation pending |
| Healthy Core | Deterministic CPU/GPU thermal-condition indicator and contextual RAM utilization | Not silicon wear or remaining-life prediction |
| Local AI | Optional Gemma 3 1B GGUF / llama.cpp analysis path | Advisory only; cannot authorize hardware writes |
| Liquid cooling | Optional external `liquidctl status --json` parsing | Read-only; no pump/fan control or leak detection |
| Diagnostics | Local structured diagnostics, redaction and export paths | Review exports before sharing |
| CPU benchmark | Bounded CPU-only benchmark | Not a GPU benchmark or stress test |
| Extension contract | Validated metadata/capability manifest | No arbitrary native plugin loading |
| Piper speech | Optional local Piper executable/model integration | User-provided runtime/model |
| Audio Controller Studio | Audio profiles and microphone processing integration | System loopback, virtual devices and per-app routing unavailable |
| Aim Trainer | Offline local practice and session statistics | No game integration or input injection |

### Partial, unavailable, or not verified

- Physical sensor, fan, battery, cooling, and power behavior has not been exhaustively validated on representative hardware.
- Windows and macOS fan writes are unavailable. Linux PWM writes require a matching valid RPM sensor, writable PWM node, and already-enabled manual mode. The bridge rechecks conditions around writes; PWM readback proves the command value, not physical fan response.
- Liquid cooling is optional and read-only.
- Windows 11 and Linux have platform-specific OS power-mode adapters; Windows 10 and macOS automated switching are unavailable. Runtime validation remains separate.
- The C++ Game Core is an early graphics component, not a complete Direct3D 12/Vulkan game engine.
- BSOD Shield contains a watchdog/heartbeat primitive; it is not a complete BSOD prevention or recovery product.
- SPARK policy code exists, but complete production-path invocation is not verified.
- RGB/ARGB, pump writes, GPU power-limit writes, clock writes, and voltage writes are not supported as general capabilities.
- Windows/macOS identity discovery must not be confused with complete per-device sensor or actuator support.

For the detailed feature-by-feature source inventory, see [Feature index](wiki/Features.md).

## 4. Hardware API capability rules

The Go bridge is the current platform-neutral boundary. Platform providers include:

| Provider | Current scope |
|---|---|
| gopsutil | Host CPU, memory, disk, uptime and exposed host sensors; provider/OS-dependent |
| Windows CIM/WMI and optional LibreHardwareMonitor WMI | Selected identity and sensor data; primarily read-only |
| Windows C# helper | Read-only system/CPU/GPU identity |
| Linux hwmon and amdgpu sysfs | Read-only telemetry plus constrained generic PWM path |
| NVIDIA `nvidia-smi` | Read-only NVIDIA telemetry |
| macOS `sysctl` / `ioreg` | Partial identity |
| liquidctl | Optional read-only USB cooling telemetry |

Mandatory invariants:

1. Sensor availability and actuator availability are independent capabilities.
2. Never infer writable control from a vendor ID, device name, GUI control, or readable sensor.
3. Missing, stale, invalid, ambiguous, or permission-denied data must not be represented as a healthy value.
4. Hardware writes require fresh safety telemetry, exact device/channel mapping, validated bounds, permissions, and surfaced errors.
5. Unsupported paths remain monitor-only.
6. A successful command-value readback is not proof of physical fan/pump response.
7. Do not silently change firmware/manual mode or invent a fallback control path.

Detailed adapter research and acceptance gates: [Hardware API vendor adapter matrix](wiki/Hardware-API-Vendor-Adapter-Matrix.md).

## 5. Security and trust boundaries

The active command boundary is the authenticated Go bridge. Security controls include request authentication, timestamp/nonce replay checks, strict command validation, bounded request handling, capability checks, and platform permissions. These controls do not eliminate the need for authorization, least privilege, dependency provenance, memory-safety review, and end-to-end tests.

Security work must cover:

- Go IPC authentication, authorization, parsing, replay, rate limits, process execution, and shutdown.
- C++ memory safety, bounds, ownership, concurrency, and error handling.
- Flutter response validation, local storage, deep links, and trust boundaries.
- Service privileges, file permissions, install paths, and privilege transitions.
- Dependency provenance, typosquatting, lockfiles, SBOM, and vulnerability response.
- Ada/SPARK inventory: identify exact units checked by GNATprove and the contracts/invariants actually proved.
- Tamper detection, safe mode, recovery, and fail-closed behavior.

Release trust layers are distinct:
- SHA-256: artifact-byte integrity.
- GitHub artifact attestation: build provenance.
- GPG/Ed25519: manifest signer authenticity when the expected public-key fingerprint is trusted.
- Windows Authenticode / macOS Developer ID and notarization: OS-recognized publisher trust.

Never commit or expose private keys, tokens, certificates, or signing passwords.

Policies and procedures:
- [Security policy](../SECURITY.md)
- [Vulnerability management](wiki/SECURITY-VULNERABILITY-MANAGEMENT.md)
- [Code signing](wiki/Security-Code-Signing.md)
- [Artifact attestation](wiki/Security-Artifact-Attestation.md)
- [Release integrity](wiki/Security-Release-Integrity.md)
- [Release verification](RELEASE-VERIFICATION.md)

## 6. Engineering completion gates

A production release is not complete until each relevant stage has evidence.

| Gate | Required evidence | Current overall assessment |
|---|---|---|
| Source/build | Reproducible CMake, Go and Flutter builds | CI result must be checked for exact commit |
| Unit/static tests | CTest, Go tests/vet, Flutter analyze/test, workflow lint | Not globally verified for current branch |
| Cross-platform build | Windows, Linux and macOS jobs | CI evidence pending per commit |
| Bridge/runtime | Authenticated request/response, UI state, reconnect, shutdown | End-to-end validation pending |
| Hardware lifecycle | Device removal/reappearance, sensor loss, fan write failures, cleanup | Partial; synthetic Linux tests do not prove physical behavior |
| Security | CodeQL, fuzz, vulnerability scans, SPARK proof, source audit | Evidence pending |
| Packaging | Expected platform packages, install/launch/upgrade/uninstall | Must be checked per release run |
| Hardware | Physical sensor, fan RPM/control and safe recovery tests | NOT VERIFIED; see matrix |
| Signing/integrity | Actual signature verification, checksums, attestations | Per-artifact evidence required |
| Release/docs | Correct tag/SHA, assets, release notes, docs synchronization | Per-release gate |

Do not suppress failing tests, use unnecessary `continue-on-error`, or call queued/cancelled workflows successful.

The detailed remaining task tracker is [Engineering Completion Roadmap](wiki/Engineering-Completion-Roadmap.md). The forward-looking feature plan is [Roadmap](wiki/Roadmap.md); it is not a completion checklist.

## 7. Platform and physical validation

Physical hardware validation is currently **NOT VERIFIED**. CI VMs, cross-compilation, synthetic sysfs fixtures, and source inspection do not count as physical hardware tests.

A platform validation record must include:
- exact device model (never publish serial numbers);
- OS build and architecture, firmware and driver versions;
- CPU/GPU/sensor values and units;
- fan inventory/RPM and control safety tests where supported;
- install, first launch, bridge communication, upgrade, uninstall and cleanup;
- redacted logs/evidence, date, and reproducible issue references.

Canonical record: [Physical Hardware Validation Matrix](HARDWARE-VALIDATION-MATRIX.md).

## 8. Build and test commands

Run commands from their relevant project directories and use the repository's pinned toolchain versions.

```sh
# Native C++ / CMake
cmake -S . -B build
cmake --build build --config Release
ctest --test-dir build --output-on-failure

# Go bridge
cd bridge_service/src
go test ./...
go vet ./...
go build ./...

# Flutter dashboard
cd gui_dashboard
flutter pub get
flutter analyze
flutter test
```

A local command is evidence only for the environment and commit where it was actually run. Record exact versions, commands, exit codes, and logs.

## 9. Packaging and release

Target artifact families:

| Platform | Target artifacts |
|---|---|
| Windows x64 | Setup EXE, MSI, portable ZIP and 7Z; MSIX preview where configured |
| Linux x64 | DEB, TAR.GZ, TAR.ZST, ZIP; APT repository is a signed repository of DEB packages |
| macOS arm64 | PKG, DMG, app-bundle ZIP containing `HWControl.app` |

An `.app` is a directory bundle. `.apt` is not a package extension. A generic `.tar.zst` is not an Arch package; native Arch packages use `.pkg.tar.zst`.

Stable release requires one immutable source SHA, all platform package gates, install/runtime smoke tests, checksums, attestations, applicable publisher signatures, and physical validation evidence. Signing credentials must be configured in GitHub Actions secrets; never paste them into chat.

Operational references:
- [Packaging overview](wiki/Packaging-and-Distribution.md)
- [Release pipeline](wiki/Packaging-Release-Pipeline.md)
- [Final release runbook](FINAL-RELEASE-RUNBOOK.md)
- [Release verification](RELEASE-VERIFICATION.md)
- [Product readiness checklist](PRODUCT-READINESS-CHECKLIST.md)

## 10. Documentation structure and source of truth

This file is the high-level project overview. Focused documents remain authoritative for their narrow operational/legal topics.

- Wiki navigation: [Wiki Index](wiki/Wiki-Index.md)
- Getting started: [Installation and platform guides](wiki/Getting-Started.md)
- Feature specifications: [Feature index](wiki/Features.md)
- Architecture: [Architecture index](wiki/Architecture.md)
- Development: [Development index](wiki/Development.md)
- Testing: [Testing index](wiki/Testing.md)
- Troubleshooting: [Troubleshooting index](wiki/Troubleshooting.md)
- Localization: [Localization roadmap](wiki/Localization-Roadmap.md)
- References: [Technical references](REFERENCES.md)
- Third-party licenses: [Third-party notices](../THIRD_PARTY_NOTICES.md)

Legal and governance documents such as LICENSE, SECURITY, PRIVACY, CODE_OF_CONDUCT, CONTRIBUTING, GOVERNANCE, and THIRD_PARTY_NOTICES must remain separate. Agent instructions, pull-request templates, component README files, and subsystem specifications must also remain in their relevant directories; merging them into a project overview would break their purpose or discoverability.

## 11. Change policy

When implementation changes:
1. Update the relevant focused subsystem document.
2. Update this master only if architecture, capability, validation, security, or release status changes.
3. Update the physical validation matrix only with reproducible physical-device evidence.
4. Update release docs only after inspecting the exact workflow run and artifacts.
5. Keep historical incident reports clearly labeled as historical.
6. Never describe planned or partially implemented behavior as shipped.
