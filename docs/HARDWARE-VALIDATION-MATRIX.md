# HWcontrol2.0 Physical Hardware Validation Matrix

Overall status: NOT VERIFIED

This matrix records physical-device evidence. GitHub-hosted VMs, CI compilation, source inspection and virtual hardware do not count as physical sensor or fan-control validation.

A platform row may be changed to VERIFIED only when the complete test record is filled in, logs are retained with sensitive values redacted, and the result is reproducible.

| Platform | Physical device / model | CPU / GPU / board | OS build / architecture | Telemetry tested | Fan RPM tested | Fan control / safety tested | Install / upgrade / uninstall | Test date | Status | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| Windows | NOT TESTED | NOT TESTED | Windows 10/11 x64 — NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — | NOT TESTED | — |
| Linux | NOT TESTED | NOT TESTED | Debian/Ubuntu x64 — NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — | NOT TESTED | — |
| macOS | NOT TESTED | NOT TESTED | macOS 14+ Apple Silicon — NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — | NOT TESTED | — |

## Required evidence per platform

- Exact physical device identifiers that are safe to publish (manufacturer/model; redact serial numbers).
- Exact OS version/build, architecture, firmware and driver versions.
- CPU and GPU identification and supported sensor readings, including units and plausible idle/load behavior.
- Fan inventory and RPM readings where the device exposes them.
- Fan-control test only where the backend explicitly reports a validated controllable channel; verify cooling floor, emergency override, permissions and safe recovery.
- Install, first launch, bridge communication, update/upgrade and uninstall/cleanup results.
- Logs or screenshots with credentials, usernames, serial numbers, network details and other sensitive values redacted.
- Test date and a reproducible issue/report reference for failures.

## Acceptance rules

1. Never mark a feature VERIFIED because its GUI control exists.
2. A missing sensor must be recorded as unavailable, not as a zero or healthy reading.
3. Unsupported fan-control hardware remains monitor-only.
4. A failed or unsafe control test blocks fan-control claims for that device and must not be hidden.
5. A platform is VERIFIED only after its full row is populated and every required safety test has a passing result.
6. The coordinated stable final-release workflow requires all three platform rows to be VERIFIED.

Until all rows are verified, the project remains Beta and the final-release workflow must stop before creating stable tags.
