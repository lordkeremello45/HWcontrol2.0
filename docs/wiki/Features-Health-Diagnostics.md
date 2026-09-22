# Health & Safety Diagnostics

HWcontrol2.0 exposes an authenticated `Get Health` bridge capability for operational health checks.

## Checks

- Authentication path
- Local transport availability
- Hardware-control capability state
- Hardware identity detection
- Sensor source availability
- Bridge version, platform and architecture

## Safety behavior

The health report is local-only and does not upload telemetry.

A `degraded` state indicates that one or more optional hardware capabilities are unavailable. It does not imply that the bridge process itself has failed.

Hardware control remains fail-closed when no native control backend is available.

## Connection protection

The bridge also enforces:

- bounded request size
- bounded authentication failures per connection
- connection read/write deadlines
- a concurrent connection ceiling
- protected bridge-key file handling
- authenticated command execution

## Validation

The security workflow runs Go formatting enforcement, `go vet`, and race-enabled tests. Cross-platform local IPC smoke tests exercise authenticated Unix sockets on Linux/macOS and loopback compatibility on Windows.
