# Frequently Asked Questions

This FAQ reflects the current documented HWcontrol2.0 architecture and implementation status. Platform- or hardware-dependent capabilities must not be interpreted as universally available.

## General

### What is HWcontrol2.0?
HWcontrol2.0 is a cross-platform desktop hardware monitoring and control application.

Architecture:
Flutter/Dart GUI → authenticated localhost Go bridge → native C++ engine → platform-specific hardware APIs.

### Which platforms are supported?
The project targets Windows 10/11 x64, Linux x64 (primarily Debian/Ubuntu-family distributions), and macOS 14+ on Apple Silicon. Individual capabilities vary by platform, driver, firmware, permissions, and hardware model.

### Is HWcontrol2.0 open source?
The project source is publicly hosted on GitHub. The repository and its license are authoritative for source and licensing information.

## Installation

### Why does HWcontrol use a bridge service?
The bridge provides a controlled boundary between the GUI and native/privileged hardware operations. It also enforces authentication, validation, rate limits, safety checks, and fail-closed behavior.

### Does HWcontrol2.0 require administrator or root privileges?
Not every operation requires elevation. Some hardware-control or platform-specific operations may require additional permissions.

On Windows, the bridge service is designed to run as NT AUTHORITY\LocalService rather than LocalSystem to reduce unnecessary privilege.

### Where should I install HWcontrol2.0?
Use the official package for your platform. Avoid manually modifying installed binaries or runtime files because integrity monitoring and release trust mechanisms may detect unexpected changes.

## Hardware

### Why is a CPU or GPU sensor missing?
Telemetry depends on the operating system, drivers, firmware, hardware model, and available sensor backend. A missing value should not be treated as a valid zero reading.

### Why can't HWcontrol control my fan?
Monitoring and control are separate capabilities. A device can expose fan RPM without exposing a safe writable fan-control interface. Unsupported or unverified control capabilities remain unavailable rather than being forced through an unsafe fallback.

### Why aren't all motherboards and GPUs supported?
Vendors expose different sensors, control interfaces, firmware behavior, and permissions. Support must be implemented and validated per backend and hardware family.

## Storage

### Can HWcontrol2.0 monitor SSDs and HDDs?
Yes. The bridge and dashboard can report mounted storage volumes, total/used/free capacity, usage percentage, and read/write throughput when the operating system exposes usable I/O counters.

### Does HWcontrol2.0 show SSD/HDD health percentage?
Not universally yet.

HWcontrol does **not** invent a health percentage when the platform does not provide a trustworthy device-health source. The current generic storage layer reports health as unknown when no platform-specific reliability backend is available.

Windows provides an official Storage Reliability Counter interface with device temperature, errors, wear, and power-on information; a native backend can use that information in a future platform-specific health implementation.

### Why can read/write speed show zero initially?
Throughput is calculated from changes in cumulative operating-system I/O counters. The first sample establishes a baseline, so a subsequent sample is required before a meaningful bytes-per-second value can be calculated.

### Can a disk being 95%+ full trigger a warning?
Yes. The hardware health engine can report a storage-near-full warning when a monitored volume reaches the configured high-utilization threshold.

## Safety and security

### What is bridge.key?
bridge.key is a credential used by the local bridge authentication mechanism. It is not intended to be exposed to ordinary users or applications.

### What happens if a critical file is modified?
HWcontrol includes runtime integrity monitoring as a defense-in-depth control. If a monitored critical target is modified, replaced, missing, or fails integrity validation, the bridge can enter a fail-closed state and sensitive hardware-control operations are stopped.

Trusted repair or reinstall is required for recovery; the system does not automatically regenerate a tampered credential.

### Is localhost automatically trusted?
No. Localhost reduces network exposure, but a local service can still form a security boundary. HWcontrol therefore applies authentication, input validation, privilege reduction, rate limiting, replay protection, file permissions, and integrity monitoring.

### Is the integrity monitor tamper-proof?
No. It is defense-in-depth and does not protect against a fully compromised administrator/root account, kernel-level compromise, or direct compromise of the monitored process.

## Health and diagnostics

### What are the hardware health states?
The health engine can use:
- SAFE
- WARNING
- CRITICAL
- FAIL_SAFE

The state considers available telemetry, detected anomalies, hardware capabilities, and integrity status.

### What happens at a critical temperature?
The safety engine can request a fail-safe recovery action such as stopping hardware control and reducing thermal load. The exact response depends on available telemetry and control capabilities.

### Does HWcontrol collect my hardware data remotely?
The project is designed around local hardware telemetry and a local bridge. Diagnostics and telemetry behavior should be evaluated against the current implementation and configuration.

### Where can I get diagnostic information?
Diagnostics expose health status, safety state, hardware capabilities, anomalies, and non-sensitive configuration state. Diagnostic export and telemetry history are also part of the project.

## Local AI

### Is the local AI required?
No. Local AI is optional and is not the foundation of hardware monitoring or safety control.

### Why is the model downloaded separately?
The local model is large compared with the core application and is handled separately. The model-management path verifies its expected SHA-256 value before accepting the model.

### Can AI directly control my hardware?
AI is not the authority for safety-critical hardware control. Hardware control remains governed by the bridge, validation, capability checks, and safety state.

## Troubleshooting

### Hardware detection failed. What should I check?
1. Confirm that the platform is supported.
2. Check the relevant driver or platform sensor interface.
3. Restart HWcontrol2.0 after hardware-driver changes.
4. Check diagnostics for detection status and available capabilities.
5. Check whether the specific backend supports the requested sensor or control.
6. Collect diagnostic information before reporting a bug.

### A fan shows RPM but fan control is unavailable. Is that a bug?
Not necessarily. RPM monitoring and writable fan control are different capabilities, and hardware or firmware may expose read-only telemetry.

### HWcontrol entered FAIL_SAFE. How do I recover?
Do not bypass the safety state. Check diagnostics for the reported anomaly or integrity failure. If integrity monitoring detected a modified critical file, use a trusted repair or reinstall path instead of manually regenerating credentials or replacing files with unverified copies.

## Development

### How is the project built?
The main components use C++/CMake for the native engine, Go for the bridge, and Flutter/Dart for the GUI. Repository build and CI workflows are authoritative for exact commands and supported environments.

### How are tests organized?
Validation includes C++/CMake/CTest, Go tests, Flutter analysis/tests, platform/package validation, security scanning, and release/package workflows. A successful source build does not prove hardware control works on every device.

### Can I add support for new hardware?
Yes. Add support through the appropriate platform/backend layer with detection logic, safe failure behavior, tests where practical, and platform/hardware validation before documenting the capability as supported.

## Releases

### What is the Beta release?
Beta builds are pre-release builds used for validation and feedback. They may change as new validated code reaches the release pipeline.

### Are all platforms guaranteed to have identical hardware capabilities?
No. The application has a common cross-platform architecture, but hardware APIs and permissions differ between Windows, Linux, and macOS.

### Does a package mean the platform is fully validated?
No. Building a package proves that an artifact was produced. Stronger release confidence requires installation, launch, runtime, hardware detection, and where applicable signing and integrity verification.

## Reporting a bug

Include:
- operating system and version
- CPU/GPU/motherboard model where relevant
- HWcontrol2.0 version or commit
- exact reproduction steps
- relevant diagnostics and logs
- whether the issue is reproducible

Never include passwords, bridge credentials, API keys, private certificates, or other secrets in bug reports.

## Documentation status

This FAQ distinguishes:
- Implemented — present in the current codebase
- Platform-dependent — depends on OS, driver, firmware, or hardware
- Planned — intended future work
- Unavailable — not currently supported

Repository source, tests, CI results, packaged artifacts, and real hardware validation remain the authoritative evidence for implementation status.
