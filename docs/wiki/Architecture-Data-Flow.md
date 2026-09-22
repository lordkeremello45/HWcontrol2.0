# Data Flow

## Telemetry

```text
CPU / GPU / RAM / Disk / Sensors
              ↓
       Go telemetry collectors
              ↓
       HardwareMetrics struct
              ↓
    HMAC-authenticated request
              ↓
        Flutter dashboard
              ↓
       cards + history graph
```

## Control

```text
User slider / preset
        ↓
Flutter command payload
        ↓
HMAC-SHA-256 authentication
        ↓
OS-native local IPC endpoint (Unix domain socket on Linux/macOS; loopback TCP compatibility on Windows)
        ↓
command validation
        ↓
hardware backend (when available)
```

## Diagnostics

The bridge also exposes authenticated security and diagnostic commands. Diagnostics include platform/runtime information, model state and digest, sensor/driver state and loopback information.
