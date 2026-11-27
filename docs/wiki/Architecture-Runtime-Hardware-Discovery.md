# Runtime Hardware Device Discovery

## Status

- Linux sysfs discovery: implemented in source; CI validation pending.
- Windows and macOS runtime device discovery: not implemented by this collector. The platform fallback intentionally returns an empty inventory rather than fabricated devices.
- Physical hardware coverage: unverified until tested on representative NVIDIA, AMD, Intel and motherboard/controller systems.

## Runtime contract

The bridge adds an additive `hardwareDevices` field to the existing metrics response. It is populated by `discoverRuntimeHardwareDevices()`; the established metrics and fan-control fields remain unchanged.

Each discovered record is validated with `HardwareDevice.Validate()`. Device IDs are opaque 16-character SHA-256 prefixes. Raw sysfs paths and serial numbers are not included in the API model. PCI GPU discovery uses the PCI vendor, product and class identifiers. hwmon interfaces are associated with their PCI device when the kernel exposes the standard `device` symlink; otherwise they are represented as an embedded controller without guessing a GPU vendor.

## Linux capabilities

The Linux collector currently:

- Enumerates PCI display-class devices and maps common PCI vendor IDs to NVIDIA, AMD and Intel.
- Reads hwmon `temp*_input` values as millidegrees Celsius and exposes them as temperature sensors.
- Reads `fan*_input` values as RPM sensors.
- Represents `pwm*` outputs as separate fan PWM actuators.
- Marks a PWM actuator writable only when its control mode is already manual (`pwm*_enable = 1`) and the bridge process can open the target for writing. Discovery never switches a controller into manual mode.
- Returns an empty slice when no supported devices are present.

PWM writability is a discovery-time permission/mode observation, not a guarantee that a later write will succeed. The write path must continue to re-check mode, bounds and readback immediately before/after a command.

## Deliberate limitations

- NVIDIA `nvidia-smi` telemetry continues through the existing metrics collector; it is not yet merged into per-device sensor records.
- AMD/Intel per-device utilization and vendor SDK telemetry are not yet normalized into this inventory.
- Windows CIM/WMI and macOS identity collectors do not yet implement per-device runtime discovery.
- Motherboard controller vendor identity is not inferred from a chip name. It is reported as `Unknown` until a validated mapping exists.
- Sensor labels are descriptive metadata, not stable identifiers. Consumers should key records by opaque device ID and component ID.

## Tests

Linux tests use temporary synthetic sysfs trees and cover PCI GPU association, temperature/RPM sensor separation, PWM actuator safety, model validation and empty discovery. They do not replace physical hardware validation.

Run from `bridge_service`:

```sh
gofmt -w src/hardware_discovery_linux.go src/hardware_discovery_linux_test.go src/hardware_discovery_other.go src/main.go
go test ./...
go vet ./...
```
