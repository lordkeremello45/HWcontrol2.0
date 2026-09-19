# Hardware Monitoring

The bridge collects system telemetry and exposes it to the Flutter dashboard.

## Current metrics

The bridge model includes:

- CPU usage
- CPU temperature
- GPU usage
- GPU temperature
- RAM usage
- disk usage
- fan percentage / RPM
- power
- voltage
- GPU vendor/name
- GPU driver state and source
- GPU memory usage
- GPU clocks
- system uptime
- sensor source

Availability depends on the operating system and installed drivers.

## Data path

```text
Hardware / OS interfaces
        ↓
Go bridge telemetry collection
        ↓
Authenticated loopback socket
        ↓
Flutter dashboard
        ↓
Charts / status cards / controls
```

The dashboard refreshes telemetry periodically and keeps a bounded temperature history.
