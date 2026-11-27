# Hardware API Contract

## Purpose

The Go bridge owns a platform-neutral hardware boundary. Flutter and the authenticated IPC protocol consume normalized metrics and capability reports; they must not call OS or vendor hardware APIs directly.

## Current adapter

`bridge_service/src/hardware_api.go` defines the `HardwareAPI` interface and the `nativeHardwareAPI` adapter. The adapter routes operations to the existing build-tagged platform implementations:

- Platform telemetry: `platform_metrics_linux.go`, `platform_metrics_windows.go`, and `platform_metrics_stub.go`.
- Fan control: `fan_control_linux.go`, `fan_control_windows.go`, `fan_control_darwin.go`, and `fan_control_other.go`.

This is an adapter boundary over the current implementations, not evidence that every platform or device has equivalent functionality.

## Contract

| Operation | Contract |
|---|---|
| `PlatformID` | Returns the Go target OS identifier |
| `CollectPlatformMetrics` | Merges optional native telemetry into a caller-owned snapshot; nil snapshots are a no-op |
| `FanControlInfo` | Reports aggregate fan-control support and backend |
| `FanChannels` | Returns independently addressable fan channels and explicit unsupported reasons |
| `SetFanPercent` | Applies a validated aggregate fan target only where a platform backend exists |
| `SetFanChannel` | Applies a validated target to the requested opaque channel ID only where supported |

## Safety invariants

1. Unsupported operations fail closed; no fallback may silently claim success.
2. Telemetry availability and actuator availability are independent capabilities.
3. Fan writes remain subject to the existing safety validation and panic-mode checks in the command path.
4. Channel identifiers are opaque values, never filesystem paths or arbitrary device addresses.
5. A successful PWM readback proves only the command value was accepted; it does not prove physical fan response.
6. Platform/device support must be reported from runtime discovery, not inferred from the operating system alone.

## Current limitations

- Linux has a constrained sysfs/hwmon PWM path for explicitly validated manual-mode channels.
- Windows and macOS fan writes remain unavailable pending validated vendor/OEM backends.
- Liquid-cooling telemetry remains optional and read-only through liquidctl.
- RGB/ARGB, pump writes, GPU power-limit writes, clock writes and voltage writes remain unsupported.
- A hardware adapter interface does not replace physical-device validation or vendor-specific integration tests.

## Validation

The bridge unit tests validate the adapter contract and fan-channel record invariants. Cross-platform CI builds are required for build-tag validation. Physical hardware tests remain separate and must identify the exact device, firmware, OS and driver tested.
