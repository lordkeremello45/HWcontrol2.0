# HWControl Service Architecture

## Status

**IMPLEMENTED (logical architecture):** six bounded services/capability areas are defined. They are not six independent daemons.

1. **Update Service** — release metadata and update verification state.
2. **SensorHealth Service** — normalized hardware telemetry, thermal safety and anomaly state.
3. **Diagnostics Service** — local crash/error/security diagnostics with redaction.
4. **Game Service** — Game Mode state and process detection.
5. **Security Guardian** — independent secondary process that observes the canary and publishes panic state.
6. **Fetch Status** — the bridge-facing canary status/integrity layer using the non-secret `bridger.key` decoy.

The first four are bounded Go Bridge modules. Security Guardian is a separate process. Fetch Status is a logical bridge service/canary layer, not a separately deployed network service or daemon.

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
          +--> Fetch Status / canary status
          |
          +--> SPARK / Rust primary security gate
          |
          +--> Security Guardian (separate process)
                        |
                        +--> observes Fetch Status canary
                        +--> writes persistent panic state
                                      |
                                      v
                                 Bridge fail-closed

The guardian does not execute hardware commands and does not receive the real `bridge.key`.

## `bridger.key`

`bridger.key` is intentionally **not** an authentication credential. It is a static, non-secret canary whose content is checked against a trusted release baseline.

The real credential remains `bridge.key`; the decoy remains `bridger.key`.

A modification, replacement, symlink substitution, disappearance, or unreadable canary is intended to cause a security event and panic mode. The deployed Guardian/Bridge behavior must be validated on each platform before this is treated as a verified runtime guarantee.

## Panic mode

Panic mode is designed to fail closed and does not retaliate against a suspected actor.

- hardware-control commands are denied;
- Game Mode control changes are denied;
- the bridge listener is stopped when its integrity/panic handling requires it;
- a local security diagnostic event is recorded;
- panic state persists until trusted recovery clears it.

The system does not automatically rewrite a tampered canary to hide the event.

## Platform isolation

### Windows

The bridge and guardian are separate Windows SCM service processes, but the current WiX configuration assigns both to `NT AUTHORITY\LocalService`. This provides process separation, **not distinct service-identity isolation**. Validate the installed ACLs and service permissions; stronger identity separation remains a hardening opportunity.

### Linux

The guardian is configured as a dedicated `hwcontrol-security` system user. Its systemd unit uses `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, read-only access to the canary directory, and write access to its panic-state directory. These controls are configuration intent until validated in a package install/runtime test.

### macOS

The guardian is installed as a separate launchd daemon. It shares the privileged installation context with the bridge in the current package design; a separate process does not by itself establish a distinct privilege boundary.

## Why this is not a normal honeytrap

The decoy is a defensive canary. It is intentionally inert: it has no privileged behavior, no real secret, no network endpoint, and no mechanism to attack an actor.

## Recovery

A panic event requires trusted recovery:

1. identify the diagnostic reason;
2. verify the installed release/package;
3. verify package checksums/provenance;
4. restore the trusted canary from the release;
5. revalidate the security chain;
6. only then clear panic state.

Automatic self-healing is intentionally not used for the security canary.
