# Application Architecture

## Verified runtime call graph

```text
Flutter / Dart Dashboard (gui_dashboard/)
        |
        | HMAC-SHA-256 authenticated command + nonce
        v
Go Bridge (bridge_service/)
  - local IPC listener and authentication
  - command validation / replay protection
  - telemetry collection and health evaluation
  - platform-specific control adapters
        |
        +--> Go / OS telemetry APIs
        |      - gopsutil
        |      - Windows PowerShell WMI / LibreHardwareMonitor WMI namespace
        |      - Linux hwmon and amdgpu sysfs
        |      - NVIDIA nvidia-smi
        |      - optional liquidctl status (read-only)
        |
        +--> platform-specific write adapters
        |      - Linux hwmon PWM (strictly capability-gated)
        |      - Windows and macOS fan writes: unavailable / monitor-only
        |
        +--> optional native helper processes
               - ai_core/ai_engine: local AI over stdin/stdout
               - audio_core helper: audio-device / audio processing operations
```

The Go bridge is the current system-facing hardware boundary. `ai_core` consumes telemetry for local analysis and does not mediate sensor collection or fan-control writes. The native audio helper is a separate concern.

The long-term shared C++ Hardware API / Cooling HAL described in the design boards is not implemented as a single runtime engine. Do not assume that a GUI widget or an AI recommendation can authorize hardware writes.

## Command and data boundaries

- Dashboard requests are serialized as JSON and authenticated with HMAC-SHA-256, timestamp and nonce.
- The bridge rejects malformed, stale, replayed and unsupported commands before dispatch.
- `Get Status` returns the Go `HardwareMetrics` contract; the dashboard parses that payload into typed UI telemetry.
- CPU usage uses nonblocking gopsutil delta sampling. NVIDIA CLI telemetry and the platform-specific collector run concurrently; results are merged after both complete.
- Hardware identity discovery is asynchronous and cached (30-minute refresh after success, one-minute retry after partial detection), so slow WMI/ioreg/lspci helpers do not hold the live status request open.
- Hardware writes are performed only by a platform adapter after a fresh thermal-safety check and capability check.
- Native AI recommendations are advisory and do not execute hardware actions.
- Optional liquid-cooling telemetry is read-only and does not initialize or reconfigure devices.
