# Hardware API vendor adapter matrix

## Purpose and status

**Status: RESEARCHED DESIGN — vendor write adapters are not yet implemented by this document.**

This page scopes the next Hardware API implementation stage. Vendor identity, a readable sensor, an installed SDK, and a writable actuator are four different facts. The bridge must report each capability independently and must never infer write support from a PCI vendor ID or telemetry result.

## Current code-backed providers

| Hardware family | Current provider in this repository | Current scope |
|---|---|---|
| NVIDIA GPU | `nvidia-smi` invoked by the Go bridge | Read-only telemetry where the driver exposes fields |
| AMD GPU on Linux | `/sys/class/drm` and amdgpu sysfs | Read-only telemetry |
| Intel GPU | No dedicated Intel adapter confirmed in the current bridge path | Unavailable until implemented and validated |
| Windows CPU/GPU sensors | CIM/WMI and optional LibreHardwareMonitor WMI | Read-only, provider-dependent |
| Linux fan controllers | hwmon PWM + matching fan RPM input | Conditional write support; only already-manual, writable channels |
| Windows motherboard/OEM fans | No validated OEM/EC, NVAPI, ADLX or IGCL write adapter wired into bridge | Monitor-only |
| macOS Apple Silicon fans | No documented public write adapter wired into bridge | Unavailable |
| USB cooling controllers | Optional external `liquidctl status --json` | Read-only telemetry |

## Vendor and OS integration targets

| Vendor / device class | Candidate API | Intended first milestone | Current HWcontrol state |
|---|---|---|---|
| NVIDIA GPU — Windows | NVIDIA NVAPI (GPU cooler interface) | Device enumeration, capability probe, read-only fan/tachometer probe; writes only after explicit device-level safety validation | Not integrated |
| NVIDIA GPU — Linux | NVML where officially available; existing `nvidia-smi` remains fallback | Structured read-only telemetry and provenance | CLI telemetry exists; NVML adapter not integrated |
| AMD GPU — Windows | AMD ADLX manual fan tuning interfaces | Capability probe and read-only device/fan discovery before any write path | Not integrated |
| AMD GPU — Linux | Kernel amdgpu sysfs/hwmon | Extend read-only sensors; PWM writes remain separate and device/driver gated | Partial read-only telemetry; generic hwmon PWM path exists |
| Intel GPU — Windows | Intel Graphics Control Library (IGCL) | Device/API version probe and read-only telemetry where supported | Not integrated |
| Intel GPU — Linux | Kernel i915/xe sysfs and hwmon interfaces | Read-only telemetry only where the kernel exposes documented attributes | No dedicated adapter confirmed |
| Motherboard / embedded controller | OEM-documented SDK or OS-supported hwmon/WMI interface | Exact board model + firmware + controller capability identification | No universal adapter |
| RGB / ARGB | Vendor-documented controller SDK/protocol | Read-only device discovery and zone enumeration before writes | Not implemented |
| AIO / custom loop | Optional liquidctl device support and documented vendor interfaces | Device topology + independent pump/fan/coolant sensor mapping | Read-only liquidctl telemetry only |
| macOS Apple Silicon | Public Apple APIs only | Documented read-only telemetry; no private SMC protocol emulation | Partial identity; fan writes unavailable |

## Adapter contract

Every vendor adapter must expose the following logical operations independently:

1. **Probe** — identify exact vendor, product/device ID, driver/API version and firmware when exposed.
2. **Discover** — enumerate physical devices and independently addressable sensors/actuators.
3. **Capabilities** — return per-device read and write capabilities, including explicit unsupported/permission-denied states.
4. **Read** — return typed values with unit, timestamp, source, validity and stale/error state.
5. **Write** — accept only an allowlisted operation for the exact discovered device and channel.
6. **Read back** — verify the device-reported command state; physical response (for example RPM) remains a separate signal.
7. **Recover** — stop issuing writes on device loss, driver/API errors, stale thermal data or bridge shutdown; return control to firmware where the documented API supports a safe handoff.

The Go bridge remains the authenticated local IPC and policy boundary. Vendor-specific native APIs belong behind isolated platform/vendor adapters; the Flutter UI must never call vendor APIs directly. Do not load arbitrary DLL/SO/dylib files or execute user-controlled command strings.

## Mandatory write-safety gates

A writable capability stays disabled until all applicable gates pass:

- Exact device and actuator mapping is stable and revalidated immediately before the command.
- API/driver/firmware combination is explicitly supported by the adapter.
- User intent and required OS permissions are present.
- Command values, units, bounds, ramp rate and command frequency are validated per device.
- A fresh, valid thermal safety source is available; missing/stale telemetry fails closed.
- Command readback is checked and errors are surfaced.
- Device disconnect, sleep/resume, bridge crash and permission loss have a documented safe behavior.
- Firmware/automatic-control restoration is implemented where supported.
- Unit tests, adapter integration tests and physical-device tests pass for the exact device/OS/driver tuple.

A successful SDK build, a passing mock test, or a PWM register readback is not proof that a physical fan/pump responded safely.

## Implementation order

1. **Vendor-neutral typed model:** device identity, sensor/actuator identity, units, provenance, capability state and error taxonomy.
2. **Read-only adapters first:** NVIDIA, AMD and Intel discovery/telemetry with bounded calls and no write side effects.
3. **Device-specific actuator adapters:** start with a narrowly supported device/driver matrix, not a universal fan-control claim.
4. **Cooling adapters:** keep pump, radiator fan, coolant temperature, flow and leak sensors as separate capabilities.
5. **RGB adapters:** enumerate controller/zone capabilities before enabling color writes.
6. **Hardware test matrix:** record exact device model, firmware, driver, OS build, permissions, expected values, observed values and recovery behavior.

## Build and licensing rules

- SDK integrations are opt-in and must not make a vendor SDK mandatory for the portable baseline build.
- If an SDK option is explicitly enabled but the official SDK is missing or incompatible, configuration must fail clearly rather than silently producing a stub.
- Do not commit proprietary SDK binaries, vendor DLLs/SOs/dylibs, private headers or credentials unless redistribution is explicitly permitted and documented.
- Pin and record SDK versions; check the applicable license and redistribution terms.
- Unsupported vendor/API combinations remain disabled; never silently fall back to another vendor's implementation.

## Authoritative implementation references

- NVIDIA NVAPI GPU Cooler Interface: https://docs.nvidia.com/nvapi/group__gpucooler.html
- NVIDIA Management Library (NVML): https://docs.nvidia.com/deploy/nvml-api/
- AMD ADLX SDK — manual fan tuning: https://gpuopen.com/manuals/adlx/adlx-sdk-references/adlx-interfaces/gpu-tuning/iadlxmanualfantuning/settargetfanspeed/
- Intel Graphics Control Library: https://intel.github.io/drivers.gpu.control-library/Control/api.html
- Linux hwmon sysfs interface: https://www.kernel.org/doc/html/latest/hwmon/sysfs-interface.html
- liquidctl: https://github.com/liquidctl/liquidctl
- Apple Developer Documentation: https://developer.apple.com/documentation/

These references are research inputs. They do not prove that a particular HWcontrol adapter is implemented or that a device is supported.
