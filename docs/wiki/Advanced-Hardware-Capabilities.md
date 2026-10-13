# Advanced Hardware Capabilities and Safety Boundaries

This page describes the current implementation, not the long-term feature target. Every writable capability must be backed by a validated platform adapter; telemetry alone never grants permission to change hardware settings.

## Implemented in the bridge

- The `Get Health` response includes a capability matrix with availability, backend and a reason when data or a supported adapter is missing.
- The matrix distinguishes read-only telemetry from writable control. GPU power-limit telemetry does not imply that writing a new limit is supported.
- Invalid CPU or memory utilization values are reported as anomalies instead of being interpreted as legitimate percentages.
- Battery capacity health is reported only when design and full-charge capacities are both available and valid. A reported capacity below 60% of design capacity raises a warning; it is a heuristic notification, not a battery replacement diagnosis.
- Thermal warnings and critical states are based on observed sensor values. Missing thermal data is not treated as a safe temperature.
- Smart fan control uses smoothing, a minimum command interval, a minimum target change, and temperature hysteresis to reduce fan-speed chatter. Invalid sensor data or an unsupported backend produces no automatic target.
- Existing dashboard thermal-throttling analysis is explicitly a suspicion heuristic based on temperature, utilization and observed clock drops. It is not equivalent to a hardware-reported throttle flag.

## Explicitly unavailable until a validated backend exists

The health capability matrix intentionally reports these as unavailable:

- CPU overclocking or voltage writes;
- GPU power-limit writes (reading a reported limit is not write support);
- battery charge-threshold control.

The app must not advertise these as working controls or attempt to emulate them through undocumented commands. Platform-specific APIs, permission handling, range validation, failure recovery and physical-hardware tests are required before changing these statuses.

## Watchdog and fail-safe scope

The current fan-curve controller fails closed when thermal telemetry is invalid or the backend is unsupported. This is a software-side guard, not a hardware-level watchdog. It cannot guarantee a fan's physical state after a process crash, power loss, firmware takeover or bridge disconnection. A true independent watchdog requires a platform/device adapter with a documented safe fallback and hardware validation.

## Validation required before production claims

- Unit tests for capability reporting, invalid readings, thermal anomalies, hysteresis and fail-closed paths.
- CI builds and tests for each supported OS.
- Physical testing on each claimed hardware/firmware combination.
- Verification that manual and automatic commands cannot bypass the capability matrix.
- Tests for service shutdown, bridge disconnect, adapter timeout and recovery.

A passing unit test or package build does not establish universal hardware support.
