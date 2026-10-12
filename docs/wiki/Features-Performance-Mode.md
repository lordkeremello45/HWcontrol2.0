# Performance Mode — Research and Implementation Plan

**Status: PHASE 3 WINDOWS + LINUX ADAPTERS IMPLEMENTED; RUNTIME VALIDATION PENDING**

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

- **Implemented adapter:** the Go bridge queries the system D-Bus property `net.hadess.PowerProfiles.ActiveProfile` using `busctl`, and supports the standard `power-saver`, `balanced`, and `performance` profiles exposed by power-profiles-daemon.
- The adapter reads the active profile before writing, sets only the requested system profile, then reads it back. If readback fails or disagrees, it attempts rollback only while the active profile still equals the value HWcontrol requested, avoiding overwriting an intervening user/system change.
- The adapter has no shell interpolation, does not write CPUFreq sysfs directly, and uses short command timeouts. If `busctl`, the service, or policy authorization is unavailable, the operation fails explicitly instead of reporting success.
- Linux power-profiles-daemon exposes one active system profile; the adapter does not claim independent AC and battery profiles. Service/polkit policy can deny writes on some systems.
- Do not directly write CPUFreq sysfs knobs as a universal solution. The Linux kernel documents that the performance governor requests the highest frequency within a policy's allowed limit, not an unconditional hardware maximum. Driver, firmware, thermal, and policy constraints still apply.
- Sources: https://freedesktop.org/software/power-profiles-daemon/ and https://docs.kernel.org/admin-guide/pm/cpufreq.html

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

1. **Phase 1 — honest UI and capability reporting:** implemented.
2. **Phase 2 — Windows 11 adapter:** implemented; runtime validation remains pending. Windows 10 is unsupported by this API path.
3. **Phase 3 — Linux adapter:** implemented through power-profiles-daemon over system D-Bus; runtime validation on a Linux host with the service remains pending.
4. **Phase 4 — macOS:** only implement automated changes after confirming a supported public API for the target OS/model matrix.
5. **Phase 5 — optional vendor adapters:** per-GPU/per-app integrations, opt-in and separately tested.

## Phase 2 — Windows power-mode adapter

- Added a Go bridge adapter using the documented Windows 11 desktop APIs in `powrprof.dll`: `PowerGetUserConfiguredACPowerMode`, `PowerGetUserConfiguredDCPowerMode`, `PowerSetUserConfiguredACPowerMode`, and `PowerSetUserConfiguredDCPowerMode`.
- The Performance Lab now exposes separate AC (plugged-in) and DC (battery) choices for Balanced, Best Power Efficiency, and Best Performance, plus a readback action. It does not automatically force Best Performance on battery.
- The bridge checks whether the APIs exist at runtime, reads the configured modes, applies only the selected supply mode, and reads back the result. If readback does not confirm the requested state, it attempts to restore the prior setting for that same supply mode.
- The bridge protocol now returns a response for successful hardware-control commands. Previously, the generic command path could execute a command without writing a success response, leaving the GUI waiting for a response timeout; this is corrected as part of the bridge integration.
- Windows 10 is unsupported by this API adapter. Linux has a separate power-profiles-daemon adapter; macOS automation remains unavailable. The effective power mode can still be overridden by Windows, firmware, thermal limits, and other system signals.
- API references:
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfiguredacpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfigureddcpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfiguredacpowermode
  - https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfigureddcpowermode
- **Validation status: UNVERIFIED.** The adapter and unit tests have been committed, but Go tests, Windows cross-compilation, and Windows 11 hardware/runtime tests have not yet been run. Do not treat this as verified support until CI and a Windows 11 smoke test pass.

## Phase 3 — Linux power-profile adapter

- Added `power_mode_linux.go`, which queries `net.hadess.PowerProfiles.ActiveProfile` using `busctl` and supports `power-saver`, `balanced`, and `performance`.
- The adapter reads the active profile before changing it, applies the requested system profile, and reads back the value. If confirmation fails, it attempts rollback only while the active profile still matches the value HWcontrol requested.
- Commands use argument arrays (no shell interpolation) and short timeouts. If `busctl`, power-profiles-daemon, or policy authorization is unavailable, the bridge returns an explicit error instead of pretending the change succeeded.
- Linux exposes one active system profile through this interface; the adapter does not claim independent AC and battery settings. It does not write CPUFreq sysfs directly or bypass thermal/firmware limits.
- Unit tests cover busctl string parsing and supported profile mappings. **Validation status: UNVERIFIED** until Go CI and a Linux runtime test with power-profiles-daemon complete.

## Current UI state

- Performance Mode toggle is available in the dashboard. Activating it plays the existing locally synthesized mode sound, opens the Performance Lab panel, and animates the dashboard accent from blue to red.
- The toggle selects the existing app-level Performance preset (fan target 85%, AI target 100%). A physical fan command is sent only when the bridge reports fan-control support; this does not imply that an OS power mode or overclock was applied.
- Performance Lab labels game-process prioritization, per-application RAM budgets, and CPU/GPU overclocking as **NOT IMPLEMENTED**. OS power-profile controls are separately available for supported Windows 11 and Linux systems; macOS automation remains unavailable.
- Generic “allocate N GiB to any application” is not a valid cross-platform promise. A future implementation must define whether it limits a managed process or configures an OS-specific mechanism, report the effective value, and avoid pretending that memory was reserved.
- No voltage, clock, power-limit, or process-priority setting is changed by the current Performance Mode toggle. OS power profiles can be changed separately from Performance Lab on supported Windows 11/Linux systems.

## Current HWcontrol2.0 status

- In-app Quiet/Balanced/Performance preset buttons: **IMPLEMENTED**, but they primarily set application-level values and only send fan commands when the bridge reports fan-control support.
- Windows 11 configured OS power-mode adapter: **IMPLEMENTED, VALIDATION PENDING**.
- Linux and macOS OS power-mode adapters: **NOT IMPLEMENTED**.
- Universal CPU/GPU clock or voltage tuning: **NOT IMPLEMENTED**.
- Per-vendor GPU driver power-mode integration: **NOT IMPLEMENTED**.
- Platform hardware behavior and performance gains: **UNVERIFIED** until tested on real supported systems.
