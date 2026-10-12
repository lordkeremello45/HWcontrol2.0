# Performance Mode — Research and Implementation Plan

**Status: RESEARCH COMPLETE; PLATFORM POWER CONTROL NOT IMPLEMENTED**

This document separates HWcontrol2.0's in-app presets from operating-system power modes and hardware fan control. A GUI preset must not be presented as a system-wide performance change unless the relevant platform backend confirms that the OS setting was changed.

## Recommended product model

Expose one user-facing preset selector (Quiet, Balanced, Performance), but represent its effects as independent capabilities:

1. **HWcontrol preset** — chooses the application's saved fan target and other settings that HWcontrol actually supports.
2. **Operating-system power mode** — an optional platform adapter requests a supported OS mode and reads back the resulting configured/effective state.
3. **Hardware cooling** — applies a fan target only when a detected backend explicitly reports fan-control support.
4. **Vendor GPU controls** — separate, optional integrations; never imply that changing the OS power mode also changes NVIDIA/AMD driver settings.

Each capability reports one of: supported, applied, unsupported, or failed. Never turn an unsupported operation into a successful preset change.

## Platform findings

### Windows

- Windows 11 exposes PowerGetUserConfiguredACPowerMode / PowerSetUserConfiguredACPowerMode for AC power and corresponding DC functions for battery power. Supported configured modes are Best Power Efficiency, Balanced (GUID_POWER_MODE_NONE), and Best Performance.
- Microsoft describes these APIs as updating the user's configured mode. Other system signals can override the effective mode, so the app should read back the state and avoid claiming that the CPU is locked to maximum performance.
- These APIs require Windows 11 desktop apps; do not assume they are available on Windows 10. On unsupported systems, report OS power-mode control as unavailable and direct users to Windows Settings rather than silently substituting an unrelated power plan.
- Keep AC and battery states distinct. A Performance preset should not force Best Performance on battery without explicit user consent.
- Sources:
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfiguredacpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfiguredacpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfigureddcpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfigureddcpowermode
  - https://support.microsoft.com/en-us/windows/change-the-power-mode-for-your-windows-pc-c2aff038-22c9-f46d-5ca0-78696fdf2de8

### Linux

- Prefer an integration with the system's existing power-profile service (for example, power-profiles-daemon through its D-Bus API) when installed and when it advertises the requested profile.
- Do not directly write CPUFreq sysfs knobs as a universal solution. The Linux kernel documents that the performance governor requests the highest frequency within a policy's allowed limit, not an unconditional hardware maximum. Driver, firmware, thermal, and policy constraints still apply.
- If no supported profile service exists, keep OS power control unavailable; do not require root access or silently modify system files.
- Source: https://docs.kernel.org/admin-guide/pm/cpufreq.html

### macOS

- Apple's Power Modes vary by model, chip, macOS version, and power source. High Power Mode is only available on specific Apple silicon models and can increase fan noise; Low Power Mode trades performance for lower energy use.
- Do not advertise a universal macOS High Power Mode switch. First detect OS version/model capability and use a documented, supported interface. Until a supported automation interface is validated, expose status/help rather than simulating a successful change.
- Source: https://support.apple.com/en-us/101613

### GPU vendor settings

- NVIDIA's “Prefer maximum performance” can help in particular cases where clock behavior is causing low FPS, but it is not a universal performance boost and can increase power use. NVIDIA also documents power-saving and frame-rate-cap options.
- Do not change global driver settings as a side effect of selecting HWcontrol's Performance preset. A future NVIDIA integration should be opt-in, per-application where possible, read back state, and restore only settings that HWcontrol itself changed.
- AMD/vendor-specific controls require their own documented and hardware-validated adapters.
- Sources:
  - https://nvidia.custhelp.com/app/answers/detail/a_id/3130/kw/system%20utility
  - https://nvidia.custhelp.com/app/answers/detail/a_id/4958/kw/power%20settings

## Safe transition contract

1. Query platform and backend capabilities before enabling a control.
2. Read and record the current OS power mode separately for AC and battery, where applicable.
3. Apply only the requested supported setting; never change voltage, clocks, power limits, or global GPU driver options as an implicit side effect.
4. Read back the configured/effective state and return an explicit result to the GUI.
5. On preset exit, restore the prior state only if HWcontrol successfully changed it and the current state still matches the value HWcontrol applied. Do not overwrite a subsequent user or OS change.
6. If the app exits unexpectedly, document that OS-mode restoration may require recovery logic; avoid persistent hidden background changes.
7. Treat thermal limits and hardware firmware as authoritative. Performance mode must never disable thermal protection or suppress Smart Fan safety behavior.
8. Test AC/battery transitions, unsupported APIs, permission failures, OS overrides, sleep/resume, repeated toggles, and rollback on each supported OS.

## Proposed rollout

1. **Phase 1 — honest UI and capability reporting:** separate in-app fan preset state from OS power mode; no privileged writes.
2. **Phase 2 — Windows 11 adapter:** implement configured-mode read/write with AC/DC separation, state read-back, rollback, and unit/integration tests. Windows 10 remains explicitly unsupported for this adapter unless a separately validated path is added.
3. **Phase 3 — Linux adapter:** integrate with a detected power-profile service and its advertised capabilities; never require root for the initial implementation.
4. **Phase 4 — macOS:** only implement automated changes after confirming a supported public API for the target OS/model matrix.
5. **Phase 5 — optional vendor adapters:** per-GPU/per-app integrations, opt-in and separately tested.

## Current HWcontrol2.0 status

- In-app Quiet/Balanced/Performance preset buttons: **IMPLEMENTED**, but they primarily set application-level values and only send fan commands when the bridge reports fan-control support.
- Cross-platform OS power-mode switching: **NOT IMPLEMENTED**.
- Universal CPU/GPU clock or voltage tuning: **NOT IMPLEMENTED**.
- Per-vendor GPU driver power-mode integration: **NOT IMPLEMENTED**.
- Platform hardware behavior and performance gains: **UNVERIFIED** until tested on real supported systems.
