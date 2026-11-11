# Hardware Monitoring

The Go bridge collects system telemetry and exposes it to the Flutter dashboard over the authenticated local IPC protocol.

## Current metrics

The bridge model includes CPU and GPU usage/temperature where exposed, RAM, storage, fan percentage/RPM, power, voltage, GPU clocks/memory, uptime, sensor provenance and collection time. Availability depends on the OS, installed drivers, device and permissions.

## Optional liquid-cooling telemetry

When an external `liquidctl` executable is installed and its hardware is supported, the bridge runs `liquidctl status --json` with a bounded timeout. It reports explicitly recognized coolant temperature, pump RPM, fan RPM, coolant flow and coolant level readings. Unsupported keys/units are ignored. Device serials and raw USB addresses are not returned.

This path is read-only: HWcontrol does not run `liquidctl initialize` or any `set` operation. Device detection does not prove AIO/custom-loop type, pump control, leak detection or universal compatibility. See [Liquid Cooling](Features-Liquid-Cooling.md).

## Data path

```text
Hardware / OS interfaces
        ↓
Go bridge collectors and platform adapters
        ↓
HardwareMetrics + capability states / provenance
        ↓
Authenticated local IPC
        ↓
Flutter dashboard
        ↓
Cards / fan channels / cooling telemetry / history graph
```

The dashboard keeps a bounded local temperature history. CPU utilization uses nonblocking delta sampling; NVIDIA and platform collectors run concurrently. Hardware identity is refreshed asynchronously and cached so slow platform inventory commands do not block the main status response. A PWM command readback is not the same as verified physical fan RPM.
