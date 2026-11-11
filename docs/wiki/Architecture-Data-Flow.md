# Data Flow

## Hardware telemetry

```text
OS / driver / sensor interfaces
        |
        v
Go platform collectors (bridge_service/src)
  - gopsutil
  - Windows WMI / LibreHardwareMonitor WMI namespace
  - Linux hwmon / amdgpu sysfs
  - NVIDIA nvidia-smi
  - optional liquidctl status --json
        |
        v
HardwareMetrics + capability / health metadata
        |
        | HMAC-authenticated response
        v
Flutter dashboard
  - typed telemetry parsing
  - fan-channel model
  - read-only liquid-cooling panel
  - history / graphs / status
```

## Hardware control

```text
User action or Smart Fan policy
        |
        v
Flutter command + timestamp + nonce + HMAC
        |
        v
Authenticated Go Bridge IPC
        |
        v
Command validation + fresh thermal telemetry + capability check
        |
        v
Platform write adapter (only where implemented)
        |
        v
Write/readback result + subsequent RPM telemetry
```

CPU utilization uses nonblocking delta sampling. NVIDIA CLI telemetry and platform-specific collectors execute concurrently; the bridge merges their results after both complete. Hardware identity collection runs asynchronously in a cache so slow WMI/ioreg/lspci helpers do not delay the main telemetry response.

The current Linux fan backend controls a validated hwmon PWM target only when its matching RPM input exists, its PWM file is writable and `pwmN_enable` is already manual mode. The write path rechecks that mode and verifies the PWM command-value readback. This readback confirms the sysfs command value, not physical fan response.

Windows and macOS fan writes remain unavailable. Liquidctl is used only for optional read-only cooling telemetry; the application does not initialize USB devices or send pump/fan commands through it.

## Native helper processes

`ai_core/ai_engine` is launched by the dashboard for local AI analysis using stdin/stdout telemetry messages. It is not in the Go hardware-control call chain. The native audio helper is likewise separate from the hardware telemetry path.
