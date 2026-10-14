# HWcontrol2.0 product context

HWCONTROL_PRODUCT_CONTEXT=v2026-10

HWcontrol2.0 is a cross-platform desktop hardware monitoring and control application with a Flutter/Dart GUI, authenticated localhost Go Bridge, native C++/CMake engine, and platform-specific hardware APIs.

## Features, subject to platform and hardware capability
- CPU/GPU temperature and load telemetry; clocks, power, and memory metrics only when exposed by the OS, driver, and device.
- Fan RPM/percentage and independent fan targets on supported Linux hwmon channels.
- Smart Fan Curve with a minimum cooling baseline, thermal emergency handling, and fail-closed behavior when control is unsupported.
- Quiet, Balanced, and Performance application profiles.
- Game Mode detects a game process and applies a supported fan profile.
- Health/anomaly diagnostics, storage telemetry, and battery-capacity health when valid capacity data is available.

## Explicit limitations
- Game Mode does not change process priority.
- Universal overclocking, voltage/clock/power-limit writes, and arbitrary per-application RAM reservation are not implemented.
- Performance Mode does not itself overclock hardware.
- OS power profiles depend on supported adapters (including Windows 11 and compatible Linux power-profiles-daemon setups); automatic macOS power-profile switching is unavailable.
- Battery health can only be calculated when valid design-capacity and full-charge-capacity values are supplied. A below-60% warning is a heuristic, not a battery-lifetime guarantee.
- The Go Bridge capability matrix and deterministic native risk assessment are authoritative.
- A GUI control or a feature description does not prove that every device or platform supports the corresponding operation.
- The local model explains supplied data; it does not issue hardware commands or replace safety checks.

Keep this document synchronized with the actual implementation and feature documentation. Mark planned or partial features clearly; never promote a goal into an implemented capability without evidence.
