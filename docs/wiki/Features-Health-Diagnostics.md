# Health, Capability & Safety Diagnostics

## Current status

**IMPLEMENTED:** HWcontrol2.0 exposes an authenticated `Get Health` bridge capability that evaluates hardware capabilities, telemetry anomalies, runtime integrity and the hardware-control safety state.

## Capability matrix

The bridge reports a per-capability matrix instead of assuming that a GUI control implies backend support:

- CPU temperature
- GPU temperature
- Fan RPM
- Fan control
- Voltage
- Power
- GPU core clock
- GPU memory clock
- GPU memory
- Hardware identity
- Storage volumes and storage I/O

Each capability reports `available`, the detected backend, and a reason when unavailable. Unsupported capabilities remain monitor-only.

## Hardware health engine

The health engine detects:

- CPU/GPU warning and critical temperatures;
- invalid thermal telemetry;
- missing thermal sensors;
- fan-stall risk when control is available but RPM is absent under thermal load;
- runtime integrity failures;
- storage volumes approaching full capacity.

The result is exposed as a structured anomaly list with a stable code, severity and human-readable message.

## Safety state machine

The bridge evaluates the current state as:

```text
SAFE
  ↓
WARNING
  ↓
CRITICAL
  ↓
FAIL_SAFE
```

The states are defensive application states, not replacements for firmware, driver or operating-system protections.

- **SAFE:** no detected safety anomaly.
- **WARNING:** thermal or telemetry degradation requires monitoring.
- **CRITICAL:** hardware-control action is blocked while the system cools.
- **FAIL_SAFE:** runtime integrity is not trusted; sensitive IPC and hardware control remain disabled until trusted repair/reinstallation.

## Recovery behavior

Recovery is deliberately fail-closed:

- thermal critical: stop hardware-control actions and reduce thermal load;
- missing thermal telemetry: reject fan-control requests;
- runtime integrity failure: stop sensitive IPC and require trusted repair/reinstallation;
- no validated hardware backend: remain monitor-only.

The application does not silently regenerate or restore tampered security-sensitive files.

## Storage monitoring

**IMPLEMENTED:** The bridge exposes mounted storage volumes with total/used/free capacity, usage percentage, and read/write throughput derived from operating-system I/O counters. The GUI displays these values per volume.

A generic health percentage is intentionally not fabricated. Storage health is reported as `unknown` until a platform-specific reliability source is available. On Windows, the official Storage Reliability Counter API exposes device temperature, errors, wear and power-on information and is a candidate for the next native backend layer. citeturn1search1turn1search0

The current storage implementation is therefore:
- **Implemented:** capacity and filesystem usage;
- **Implemented:** read/write throughput where OS I/O counters can be mapped to the volume;
- **Platform-dependent:** device temperature and health/wear percentage;
- **Not implemented:** a universal cross-platform SMART/NVMe health percentage.

## Existing diagnostics and history

The dashboard already provides:

- diagnostic report export;
- persistent telemetry history;
- configurable temperature alerts;
- local profile persistence;
- update checking.

The new health evaluation is also included in the bridge diagnostic snapshot so exported diagnostics can explain the detected capability/safety state.

## Security model

The design follows a defense-in-depth model consistent with NIST secure software development guidance. Runtime SHA-256 monitoring remains a detection control; release signing/provenance is the stronger trust chain. Linux deployments can additionally use filesystem mechanisms such as fs-verity where supported.

## Validation

Go unit tests cover:

- capability-matrix availability;
- thermal anomaly detection;
- fan-stall detection;
- integrity-triggered FAIL_SAFE state;
- storage capability and near-full detection;
- diagnostics contract.

Cross-platform runtime validation still depends on the repository's GitHub Actions and real hardware/device coverage.
