# Hardware Abstraction

## Current implementation

The current hardware-collection and supported-control boundary is implemented in `bridge_service/src` (Go). There is not yet one shared C++ Hardware API that owns all platform collectors and writes.

| Capability / platform | Current provider | Status |
|---|---|---|
| CPU, memory, disk, uptime and host sensors | gopsutil in the Go bridge | Partial; depends on OS and driver exposure |
| Windows CPU/GPU/fan/power telemetry | PowerShell CIM/WMI and LibreHardwareMonitor WMI namespace when its service is available | Partial, read-only |
| Windows hardware identity | Packaged C# WMI helper with PowerShell fallback | Read-only identity; not a fan-control adapter |
| Linux AMD GPU telemetry | `/sys/class/drm` and amdgpu sysfs | Partial, read-only |
| Linux NVIDIA GPU telemetry | `nvidia-smi` | Partial, read-only |
| Linux fan channels | `/sys/class/hwmon` PWM and matching fan RPM inputs | Writable only when validated, already in manual mode and permissions allow |
| macOS hardware identity | `sysctl` and `ioreg` | Partial, read-only |
| macOS fan control | No validated write adapter | Unavailable / monitor-only |
| USB cooling controllers | Optional external `liquidctl status --json` | Read-only, per-device/per-sensor |

## Bridge-to-GUI contract

The Go bridge returns a `HardwareMetrics` response for `Get Status`. Fan channels are independently enumerated and expose opaque IDs, backend, writable state, RPM feedback, PWM percentage and a reason when they remain monitor-only.

The `Get Health` response adds a capability matrix. Each capability reports:

- `available`: whether a validated value or operation is present;
- `state`: `available`, `unavailable`, `permission_denied` or `unsupported`;
- `backend`: the provider that reported it;
- `reason`: why the capability is missing or restricted.

Monitoring a sensor never implies that its actuator is writable.

## Fan write safety

Linux fan writes require a discovered `pwmN` target with a corresponding `fanN_input` RPM measurement, permission to write, and an existing `pwmN_enable=1` manual-mode state. The bridge rechecks the mode immediately before writing and reads the PWM command back after the write. It does not silently switch firmware-controlled channels into manual mode.

The PWM readback validates the sysfs command value only. Physical RPM response remains a separate telemetry signal and hardware validation requirement.

## Liquid-cooling adapter

The optional liquidctl integration executes only `liquidctl status --json`. It uses bounded execution time/output, normalizes a strict allowlist of key/unit pairs and discards serial numbers and raw USB addresses. It does not run `initialize` or `set` commands.

AIO/custom-loop topology is not yet classified. Pump/fan control, device-specific fallback, leak detection and physical hardware validation remain separate requirements. See [Liquid Cooling](Features-Liquid-Cooling.md).

## Target architecture

The Notion/Miro design proposes a common Hardware API contract, capability registry, isolated vendor/platform adapters, watchdog/fallback policy and a Cooling HAL. These remain a target architecture. Do not describe them as implemented until the interfaces are wired into the runtime, tested and validated on physical devices.
