# HWcontrol2.0 — Project Summary

> **Status: Beta / active development.** This document explains the project's purpose, architecture, intended behavior, technology choices, prototypes, and current limitations. It is an orientation document, not a certification or a claim that every feature has passed end-to-end testing.

## 1. What the project is

HWcontrol2.0 is an open-source, cross-platform desktop application for monitoring PC hardware, presenting telemetry, diagnosing selected conditions, and controlling supported hardware through guarded control paths.

It aims to bring hardware information and supported controls into one desktop interface instead of requiring users to move between multiple utilities. The project is intended for ordinary PC users and developers who want a more inspectable, extensible hardware-monitoring and control tool.

HWcontrol2.0 is a desktop PC utility. It is **not** an industrial SCADA system, a serial hardware-flow-control protocol, or a digital audio workstation/mixer.

## 2. Why it is being built

The project aims to:

- present CPU, GPU, memory, storage, temperature, fan, and other available telemetry in one place;
- provide history, graphs, alerts, diagnostics, and clear explanations when data or controls are unavailable;
- expose fan curves, fan profiles, and performance modes only when the platform and device support them safely;
- use a layered architecture so the GUI is not directly responsible for privileged hardware operations;
- keep security checks, input validation, release integrity, and safe failure behavior part of the engineering design;
- support Windows, Linux, and macOS through platform-specific adapters rather than pretending every device behaves identically;
- remain open source, testable, and maintainable, with documentation that distinguishes current implementation from future goals.

The project's guiding rule is that **a visible GUI control does not prove that the corresponding hardware operation is implemented or supported**.

## 3. How it works

The intended high-level request and data flow is:

```text
User
  ↓
Flutter / Dart desktop GUI
  ↓ authenticated localhost requests
Go Bridge
  ├─ request authentication and validation
  ├─ routing, diagnostics, and platform adapters
  └─ security-policy integration points
  ↓
Native C++ / CMake engine and supporting native modules
  ↓
Operating-system APIs, drivers, and device interfaces
  ↓
Telemetry / supported hardware operation
  ↑
Validated result returned through the bridge to the GUI
```

The layers have different responsibilities:

1. **GUI — Flutter/Dart:** presents the dashboard, user settings, graphs, profiles, diagnostics, and user-facing errors.
2. **Bridge — Go:** provides the local communication boundary between the GUI and backend services. The repository documents loopback communication authenticated with HMAC-SHA-256. Authentication does not replace per-command authorization, validation, or safe hardware capability checks.
3. **Native engine — C++17/CMake:** hosts native functionality and platform-facing code. Hardware access must depend on the actual OS, driver, permissions, and device capability.
4. **Platform adapters:** obtain telemetry or perform operations through platform-specific mechanisms. Unsupported or unsafe control paths should remain monitor-only.
5. **Security policy — Ada/SPARK:** expresses contracts and fail-closed decisions for selected safety-sensitive inputs and commands. Its existence does not mean every runtime request already passes through the SPARK code.
6. **Supporting components:** Rust support code, a Windows C# hardware-identity collector, and optional local AI/audio components exist in the repository's broader design. Each has a specific boundary and must not be treated as an authorization source unless explicitly implemented and verified.

## 4. Technology stack

| Technology | Intended role |
|---|---|
| Flutter / Dart | Cross-platform desktop interface |
| Go | Local bridge, request handling, and platform integration |
| C++17 / CMake | Native engine and native modules |
| Ada/SPARK | Contract-based safety policy and formal-analysis target |
| Rust | Supporting native/FFI boundary code where enabled |
| C# | Windows hardware-identity metadata collection; read-only/untrusted input |
| GitHub Actions | Automated build, test, package, security, and release workflows |
| CMake / CTest | Native configuration and test entry points |
| GNAT / GNATprove | Ada compilation and SPARK formal analysis |
| Optional local Gemma GGUF model via llama.cpp | Local AI experiments/features when the model is separately available |
| miniaudio | Cross-platform audio-device layer used by the native audio component |

The exact components built into a given package depend on the relevant build configuration. An optional model is a runtime asset and is not guaranteed to be bundled or installed.

## 5. Security design and Ada/SPARK

The repository includes an Ada package under `security/spark-core/` using `SPARK_Mode => On`. Its policy includes sensor-temperature bounds, a critical-temperature threshold, fan-command range checks, telemetry validity, authorization, and integrity-state checks. Invalid or unsafe inputs should result in a deny decision.

The security core also documents C-compatible entry points for fan-command and hardware-identity validation. The Rust support layer can use the SPARK FFI feature where enabled.

**Important integration boundary:** the SPARK policy and its exported ABI are not proof that the production application calls them on every relevant request. The SPARK core's own README states that the Windows Go adapter currently applies a matching fail-closed contract but does not yet dynamically link or invoke the Ada symbol. Cross-platform native linking and end-to-end enforcement remain validation work. Do not interpret SPARK as a replacement for cryptographic libraries, bridge authentication, operating-system permissions, or hardware capability checks.

Security goals include:

- authenticate local bridge requests;
- validate and bound untrusted inputs;
- authorize each sensitive operation;
- fail closed when integrity, telemetry, or validation is unknown or unsafe;
- avoid treating hardware-identity metadata as an authorization token;
- protect secrets and redact sensitive diagnostic data;
- verify package integrity and clearly distinguish checksums, provenance attestations, code signing, and notarization.

No security mechanism proves that a whole application is invulnerable. The actual protection level depends on integration, tests, review, platform behavior, and release configuration.

## 6. Features and capability model

The project describes the following feature areas, subject to implementation and platform support:

- CPU/GPU, memory, storage, fan, temperature, and other available sensor telemetry;
- temperature history, graphs, and alerts;
- storage usage and read/write throughput, with health status only when a trusted platform source is available;
- fan inventory, manual targets, fan curves, and local profiles on validated channels;
- Performance / Balanced / Quiet profiles and Game Mode where supported;
- hardware capability reporting, bridge diagnostics, anomaly detection, and fail-safe health states;
- local user settings and persistent telemetry/profile data;
- optional local AI support;
- native audio functionality under `audio_core/`;
- build, package, checksum, and provenance automation.

These are repository feature areas, not a guarantee that every bullet is complete on every operating system. Sensor monitoring does not imply that a sensor can be controlled, and a fan-curve editor does not imply that a device exposes safe writable fan channels.

## 7. Architecture sketches, schemas, and prototypes

The primary architecture sketch is the layered flow in Section 3. The project also contains narrower component designs and contracts, including:

- **SPARK policy contracts:** explicit preconditions/postconditions and deterministic allow/deny decisions for selected safety-sensitive inputs.
- **C ABI boundary:** exported validation functions intended to make the policy callable from foreign-language components without relying only on Ada-specific types.
- **Hardware identity schema:** the Windows C# collector's JSON is treated as untrusted metadata; schema, payload bounds, counts, and status are validated before the data is accepted.
- **Capability-based control model:** the application should only offer or execute controls when the platform/device capability has been detected and validated.
- **Optional AI model path:** local AI is an optional support component; core monitoring must not depend on a model being present.
- **Native audio component:** `audio_core/` is included by the root CMake configuration; its presence does not prove that every planned audio feature is complete or packaged.

These are component-level designs and implementation paths, not evidence that the complete application has passed an end-to-end acceptance test. For exact interfaces and current implementation details, inspect the linked source and component READMEs.

## 8. Target platforms and packaging

The currently documented release targets are:

| Platform | Target | Documented package formats | Status |
|---|---|---|---|
| Windows | Windows 10/11, x64 | EXE, MSI, MSIX, portable ZIP | Beta |
| Linux | Debian/Ubuntu-family, x64 | DEB, TAR.GZ, TAR.ZST | Beta |
| macOS | macOS 14+, Apple Silicon/arm64 | PKG, DMG containing an app bundle | Beta |

Windows ARM64 and Intel macOS packages are not currently documented as shipped targets.

A build target is not a compatibility guarantee. Real hardware behavior depends on the model, firmware, driver, OS APIs, permissions, and competing control software.

## 9. Current state and known gaps

The repository describes HWcontrol2.0 as **Beta and under active development**. The README, honest-description document, SPARK component README, and product-readiness checklist intentionally distinguish implementation from verified readiness.

Known limitations include:

- no complete, regularly maintained VM and physical-hardware compatibility matrix;
- no universal sensor, fan-controller, motherboard, laptop, or GPU support;
- selected hardware controls may be unavailable and must remain monitor-only;
- end-to-end SPARK invocation and native linking are not yet verified across all release platforms;
- optional AI model availability is separate from the core build;
- a CI pass validates only the checks and environment in that workflow, not every hardware configuration;
- trusted OS publisher signing/notarization must only be claimed when release-specific evidence exists.

For current status, check the [README](README.md), [Honest Description](docs/honestdescription.md), [Product Readiness Checklist](docs/PRODUCT-READINESS-CHECKLIST.md), [SPARK Security Core README](security/spark-core/README.md), release notes, and current GitHub Actions runs. This summary does not replace those sources or assert that their checklists are all complete.

## 10. Validation and release philosophy

The intended validation lifecycle is:

```text
Source inspection
  → Build and compile
  → Unit and integration tests
  → Formal analysis where applicable
  → Platform package creation
  → Install / launch / runtime smoke tests
  → Hardware-specific validation
  → Integrity and signing checks
  → Release notes and documentation
```

A package existing is not proof that installation and runtime behavior work. A successful build is not proof of sensor accuracy, safe fan control, complete security integration, or compatibility with all devices. Each claim should be tied to a reproducible test, a specific platform/device configuration, or explicit source-level evidence.

## 11. Licensing and project links

The root README documents the desktop application under **GNU GPLv3**, the website source under **GNU AGPLv3-only**, local security tooling under **Apache-2.0**, and third-party components under their respective licenses. Always check the applicable license file for the specific component.

- Main repository: https://github.com/lordkeremello45/HWcontrol2.0
- Releases: https://github.com/lordkeremello45/HWcontrol2.0/releases
- Project website: https://lordkeremello45.github.io/HWcontrol2.0/
- Wiki: https://github.com/lordkeremello45/HWcontrol2.0/wiki
- Security policy: [SECURITY.md](SECURITY.md)
- User quickstart: [docs/USER-QUICKSTART.md](docs/USER-QUICKSTART.md)
- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)

## 12. In one sentence

**HWcontrol2.0 is an open-source, layered desktop platform intended to make PC hardware telemetry, supported controls, diagnostics, and safety-conscious operation easier to use across operating systems—while documenting what is implemented, what is platform-dependent, and what still needs proof.**
