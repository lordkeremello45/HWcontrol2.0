# HWControl Service Architecture

## Status

**IMPLEMENTED:** six bounded service modules are present in the Go bridge.

1. **Update Service** — release metadata and update verification state.
2. **SensorHealth Service** — normalized hardware telemetry, thermal safety and anomaly state.
3. **Diagnostics Service** — local crash/error/security diagnostics with redaction.
4. **Game Service** — Game Mode state and process detection.
5. **Security Service** — independent secondary security guardian process that enforces the panic state.
6. **Fetch Status Service** — canary/deception service using the non-secret `bridger.key` decoy.

The six services are deliberately not six network microservices. The first four are bounded bridge modules because they do not require independent privilege or process lifecycles. Services 5 and 6 have an independent process boundary because they form the defense-in-depth security path.

## Security boundary

    Flutter / Dart
          |
          v
    Authenticated Go Bridge
          |
          +--> Update
          +--> SensorHealth
          +--> Diagnostics
          +--> Game
          |
          +--> SPARK / Rust primary security gate
          |
          +--> Security Guardian (separate process)
                        |
                        +--> Fetch Status canary
                        |       |
                        |       +--> bridger.key integrity
                        |
                        +--> panic-mode state
                                |
                                v
                           Bridge fail-closed

The security guardian does not execute hardware commands and does not receive the real `bridge.key`.

## `bridger.key`

`bridger.key` is intentionally **not** an authentication credential. It is a static, non-secret canary whose only security property is that it must match the trusted release baseline.

The real credential remains `bridge.key`; the decoy remains `bridger.key`.

A modification, replacement, symlink substitution, disappearance, or unreadable canary causes a security event and enters panic mode.

## Panic mode

Panic mode is fail-closed. It does not retaliate against the suspected actor.

- hardware-control commands are denied;
- Game Mode control changes are denied;
- the bridge listener is stopped;
- a local security diagnostic event is recorded;
- the panic state remains until trusted recovery/reinstallation clears it.

The system does not automatically rewrite a tampered canary to hide the event.

## Platform isolation

### Windows

The bridge and guardian use Windows Service Control Manager services. The guardian is a separate service process and uses `NT AUTHORITY\LocalService`, a predefined low-privilege service account. See Microsoft documentation for LocalService and service account selection.

### Linux

The guardian is a dedicated `hwcontrol-security` system user. Its systemd unit uses `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, read-only access to the canary directory, and write access only to its panic-state directory. systemd supports these filesystem and privilege-reduction controls for long-running services.

### macOS

The guardian is a separate launchd daemon and is installed independently from the bridge daemon.

## Why this is not a normal honeytrap

The decoy is a defensive canary. It is intentionally inert: it has no privileged behavior, no real secret, no network endpoint, and no mechanism to attack the actor.

OWASP describes canary files/records as deceptive assets whose unexpected access can indicate malicious reconnaissance or tampering.

## Recovery

A panic event requires trusted recovery:

1. identify the diagnostic reason;
2. verify the installed release/package;
3. verify package checksums/provenance;
4. restore the trusted canary from the release;
5. revalidate the security chain;
6. only then clear panic state.

Automatic self-healing is intentionally not used for the security canary.
