# Advanced Hardware Capabilities

## Implemented in the Go bridge

- `Get Health` exposes capability availability, explicit state, backend and an explanation for unavailable or unsupported sensors/control paths.
- Read-only telemetry and writable fan channels are evaluated separately.
- GPU power-limit telemetry does not imply that power-limit writes are available.
- Linux fan control requires a matching RPM input, a writable PWM attribute and an already-active manual mode.
- Each PWM write rechecks the manual-mode state and reads back the requested PWM command value.
- The bridge and dashboard enforce a 20% minimum manual/curve fan target; this is a project safety policy, not a promise that every fan starts reliably at 20%.
- Optional liquidctl telemetry is read-only and capability-gated.

## Explicitly unavailable or partial

- Windows fan writes: unavailable pending validated vendor/OEM adapter integration.
- macOS fan writes: unavailable.
- Pump control, AIO/custom-loop topology, leak detection, universal flow/level support and physical cooling fallback: not implemented.
- Ada/SPARK is present for selected policy logic, but its production runtime invocation across the complete command path remains unverified.
- A shared C++ Hardware API / Cooling HAL remains a target architecture, not the active telemetry/control path.
