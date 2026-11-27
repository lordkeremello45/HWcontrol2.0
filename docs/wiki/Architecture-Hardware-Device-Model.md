# Vendor-neutral Hardware Device Model

**Status: IMPLEMENTED — standalone model and validation; runtime enumeration integration is pending.**

The Go bridge now has a typed, vendor-neutral representation for a hardware device, its identity, sensor readings, actuators and per-device capabilities.

## Model

- `HardwareDevice`: opaque device ID, identity, provider backend and component collections.
- `HardwareDeviceIdentity`: vendor, device class, optional product/revision/model and driver metadata.
- `HardwareSensor`: typed kind/unit/value, source, observation timestamp and freshness state.
- `HardwareActuator`: typed kind/unit, permitted numeric range, writable state, backend and an explanation when unavailable.
- `HardwareCapabilityRef`: independent read/write permissions and explicit availability state.

## Validation invariants

- Device IDs are opaque 16-character hexadecimal identifiers; component IDs allow only ASCII letters, digits, underscore and hyphen.
- Available sensor values must be finite and timestamped.
- Sensor and actuator component IDs must be unique within a device.
- Actuator bounds must be finite and ordered.
- A non-writable actuator must provide a reason. A writable actuator cannot carry an unavailable reason.
- Unsupported, unavailable and permission-denied capabilities cannot advertise read or write permission.
- Serial numbers, raw USB addresses and filesystem paths are intentionally excluded.

## Scope boundary

This model is not yet populated by the live Linux, Windows or macOS collectors. Existing telemetry and fan-control paths continue to operate as before. The next integration step is to map platform discovery into this model without changing the existing bridge response contract prematurely.

## Tests

`hardware_device_model_test.go` covers valid devices, unsafe identifiers, non-finite sensor values, missing timestamps, duplicate component IDs, actuator write-state consistency and capability-state consistency.

A source commit is not evidence of a passing Go build. Run `go test ./...` and `go vet ./...` from `bridge_service/src` in CI or a supported Go 1.26.11 environment before marking the code VERIFIED.
