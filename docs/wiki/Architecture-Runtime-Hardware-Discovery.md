# Runtime Hardware Device Discovery

## Status

- Linux sysfs discovery: implemented in source; CI validation pending.
- Windows and macOS identity discovery: implemented using the existing Windows C# / CIM identity collector and macOS sysctl/ioreg identity collector. These adapters currently emit identity-only system, motherboard, CPU and detected GPU records; per-device sensor and actuator collection remains unimplemented.
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

## Vendor telemetry normalization

The existing NVIDIA `nvidia-smi`, Linux AMD `amdgpu/sysfs`, Linux Intel DRM sysfs clock/memory/temperature interfaces, and Windows LibreHardwareMonitor/WMI metric collectors are mapped into the discovered GPU record through the shared telemetry adapter. Attribution is deliberately conservative: telemetry is attached only when exactly one discovered GPU matches the reported vendor. Aggregate readings are not assigned when multiple same-vendor GPUs make the target ambiguous. GPU utilization includes an explicit internal source marker so a legitimate 0% reading is distinguishable from an unavailable value. The bridge validates the enriched device model before returning it. Each metrics collection rebuilds the discovery slice from the current platform inventory rather than retaining a process-wide device cache; devices absent from the next scan are therefore omitted instead of being served as stale hardware records. Per-device temperature provenance is mandatory: the bridge does not copy the shared, potentially cross-device `SensorSource` into CPU and GPU source fields, because doing so can attribute one adapter's reading to another device. Thermal-safety availability is based only on an explicitly sourced, range-valid CPU or GPU temperature. The model enforces canonical sensor kind/unit pairs (`temperature/celsius`, `fan-speed/rpm`, `utilization/percent`, memory byte counters, `power/watts`, and `clock/megahertz`), finite values and kind-specific ranges. It also rejects a device record whose reported used-memory value exceeds its reported total-memory value. Fan actuators are checked against their canonical units and safe declared bounds (`fan-pwm/raw-0-255`, `fan-speed/percent` or `fan-speed/rpm`). Zero and valid subzero temperature readings are preserved when a collector supplies an explicit source marker. This applies at collection, platform-merge and device-normalization boundaries; a valid reading must not be dropped merely because it is not greater than zero.

## CPU, memory and motherboard telemetry

CPU utilization and frequency are sourced from gopsutil; CPU temperature is published only when the platform sensor collector supplies a validated reading and source. The fast fan-safety sampling path uses the same canonical temperature range and explicit CPU/GPU source requirement as the normal metrics path; it never promotes the shared generic source to a device-specific source. Windows WMI output carries separate presence flags so an absent sensor (serialized numerically as zero) cannot be confused with a real zero-degree reading. The bridge emits a CPU device record after platform identity has been collected, so the model/vendor is not guessed from utilization alone. System memory is represented as a separate device with measured used/total byte counts and utilization from gopsutil.

On Linux, known hwmon drivers are classified conservatively: `coretemp`, `k10temp` and `zenpower` are CPU thermal sources; recognized NCT/IT87/W836 and selected OEM EC drivers are motherboard-controller sources. Their actual temperature, fan RPM and PWM interfaces are retained as sensor/actuator components. Unrecognized hwmon devices remain generic embedded controllers. Motherboard vendor/model metadata is attached only to records already identified as motherboard controllers; it does not manufacture sensor capabilities.

## Windows and macOS scope

The non-Linux adapter converts the existing platform identity result into validated device records. It does not infer sensor readings, fan channels, writable controls, or capability support from a device name. A missing GPU model produces no GPU record. Windows currently receives the single preferred GPU summary exposed by the existing identity contract; complete multi-GPU enumeration needs a richer inventory contract. macOS reports the Apple system/CPU identity where available; Apple GPU records are emitted only when the platform collector supplies a concrete GPU model.

## Deliberate limitations

- Intel GPU utilization is not inferred where the kernel does not expose a supported counter through the selected sysfs interface. Vendor SDK telemetry and indexed multi-GPU attribution remain unimplemented.
- Windows combines identity discovery with aggregate CPU/GPU telemetry from LibreHardwareMonitor WMI when that provider is installed, plus limited WMI fallback data. The current Windows collector selects a single preferred GPU/sensor set; indexed multi-GPU attribution and native fan actuator control remain unimplemented.
- macOS discovery currently emits identity-only records. Native per-device sensor and actuator adapters remain unimplemented.
- Motherboard controller vendor identity is not inferred from a chip name. It is reported as `Unknown` until a validated mapping exists.
- Sensor labels are descriptive metadata, not stable identifiers. Consumers should key records by opaque device ID and component ID. Linux fan PWM actuator IDs and the bridge FanChannel IDs are generated by the same stable channel-identity function, including collision handling for multiple hwmon interfaces on one parent controller.

## Tests

Linux tests use temporary synthetic sysfs trees and cover PCI GPU association, CPU/motherboard hwmon classification, temperature/RPM sensor separation, PWM actuator safety, Intel DRM telemetry parsing, conservative vendor attribution, model validation and empty discovery. Cross-platform unit tests cover CPU, memory and motherboard identity-to-device mapping. Non-Linux tests cover identity-to-device conversion, deterministic opaque IDs and the no-invented-GPU rule. These tests do not replace physical hardware validation.

Run from `bridge_service`:

```sh
gofmt -w src/hardware_discovery_linux.go src/hardware_discovery_linux_test.go src/hardware_discovery_other.go src/hardware_discovery_other_test.go src/hardware_device_telemetry.go src/hardware_device_telemetry_test.go src/hardware_cpu_telemetry.go src/hardware_cpu_telemetry_test.go src/platform_metrics_linux.go src/platform_metrics_linux_test.go src/platform_metrics_windows.go src/main.go
go test ./...
go vet ./...
```
