# Engineering Completion Roadmap

## Purpose

This document tracks the remaining engineering work required before HWcontrol2.0 can be considered production-ready. A checkbox is not a claim of implementation. Every item must be closed with code evidence, automated tests, platform validation, or an explicitly recorded external blocker.

## Status vocabulary

- **IMPLEMENTED**: source implementation exists; this does not imply platform or hardware validation.
- **PARTIAL**: some paths exist, but coverage or lifecycle behavior is incomplete.
- **NOT IMPLEMENTED**: no production implementation has been verified.
- **UNVERIFIED**: implementation may exist, but the required build, CI, package, runtime, or hardware evidence is absent.
- **BLOCKED**: requires external hardware, credentials, signing identity, or a platform runner.

## 1. Hardware API lifecycle and failure handling

Status: **PARTIAL**. Linux discovery is rebuilt from the current sysfs inventory for each metrics collection. Removed devices are omitted on the next scan. Linux PWM writes re-check manual mode and fresh RPM feedback and verify the write by reading back the target. This is not a watchdog or a complete cross-platform recovery system.

- [ ] Verify device removal and reappearance across consecutive discovery scans.
- [ ] Verify missing, malformed, out-of-range, and permission-denied sensor reads never reuse stale values.
- [ ] Verify sensor state and observation timestamps have consistent semantics across all collectors.
- [ ] Verify a fan channel disappearing between discovery and command execution fails closed.
- [ ] Verify PWM open/write/readback failures return errors and never produce a success response.
- [ ] Define and test safe behavior after a fan-control backend failure; do not silently switch manual/automatic mode.
- [ ] Define recovery policy for controller reset, service restart, and device reconnect.
- [ ] Implement a watchdog only after its ownership, timeout, escalation, and safe-state semantics are specified.
- [ ] Validate cleanup of device, sensor, actuator, and capability records after every rescan.
- [ ] Add deterministic fault-injection tests for filesystem errors and disappearing sysfs nodes.

## 2. Hardware coverage and vendor adapters

Status: **PARTIAL**. Linux sysfs discovery and selected telemetry adapters exist. Windows and macOS identity discovery must not be confused with complete sensor or actuator support.

- [ ] Validate CPU temperature, utilization, frequency, and per-core attribution on representative Intel and AMD systems.
- [ ] Validate NVIDIA, AMD, and Intel GPU temperature, utilization, memory, power, and clock telemetry independently.
- [ ] Add indexed per-device telemetry for multiple GPUs; never attach ambiguous aggregate readings to an arbitrary device.
- [ ] Validate multi-socket CPU inventory and per-socket telemetry.
- [ ] Validate motherboard, embedded-controller, and OEM sensor attribution.
- [ ] Improve Linux hwmon identity stability where multiple interfaces share a parent device.
- [ ] Evaluate Windows per-device sensor collection and native fan-control backends.
- [ ] Evaluate macOS sensor and fan-control APIs; retain identity-only behavior until a supported and safe backend exists.
- [ ] Document vendor, kernel, driver, permissions, and hardware limitations for each adapter.
- [ ] Run physical hardware validation on representative NVIDIA, AMD, Intel, laptop, desktop, and motherboard-controller configurations.

## 3. Bridge and native engine integration

Status: **UNVERIFIED** until complete end-to-end evidence is attached.

- [ ] Verify Flutter request construction, endpoint selection, response decoding, and visible UI state.
- [ ] Verify authenticated localhost Go Bridge to native C++ Engine request/response lifecycle.
- [ ] Verify request deadlines, cancellation, bounded payloads, and deterministic error mapping.
- [ ] Verify malformed, replayed, unauthenticated, oversized, and unauthorized requests are rejected.
- [ ] Verify service startup ordering, engine availability checks, crash handling, and clean shutdown.
- [ ] Verify reconnect behavior after bridge or engine restart.
- [ ] Verify long-running telemetry collection does not leak goroutines, file descriptors, handles, or memory.
- [ ] Add cross-layer contract tests for metrics, fan control, profiles, and hardware inventory.

## 4. Security and trust boundaries

Status: **PARTIAL / UNVERIFIED**. Existing controls require a full-source audit and reproducible evidence.

- [ ] Audit C++ memory safety, integer overflow, bounds, ownership, and error paths.
- [ ] Audit Go Bridge authentication, authorization, IPC, input validation, and process execution.
- [ ] Audit Flutter trust boundaries, local storage, deep links, and response validation.
- [ ] Review service privileges, filesystem permissions, installation paths, and privilege transitions.
- [ ] Review dependency provenance, typosquatting exposure, lockfiles, SBOM, and vulnerability response.
- [ ] Verify secrets and signing material are absent from source, logs, artifacts, and CI output.
- [ ] Inventory Ada/SPARK code and prove which packages are actually checked by GNATprove, including contracts and loop invariants where applicable.
- [ ] Verify safe mode, tamper detection, recovery, and fail-closed behavior.
- [ ] Perform threat modeling for local IPC, update delivery, plugins, and hardware-control commands.
- [ ] Add security regression tests for every confirmed finding.

## 5. Automated tests and CI

Status: **UNVERIFIED** until current branch workflow results are inspected.

- [ ] Obtain passing Go test and go vet results.
- [ ] Obtain passing CMake configure/build and CTest results.
- [ ] Obtain passing Flutter dependency resolution, analyze, and test results.
- [ ] Verify Windows x64 build on a Windows runner.
- [ ] Verify Linux x64 build on a Linux runner.
- [ ] Verify macOS 14+ Apple Silicon build on an appropriate macOS runner.
- [ ] Add regression tests for every fixed defect and every hardware safety invariant.
- [ ] Add race, fuzz, static-analysis, and dependency checks where appropriate.
- [ ] Ensure CI failures remain visible; do not skip, suppress, or continue-on-error around required checks.

## 6. Packaging, installation, and release

Status: **UNVERIFIED** until lifecycle tests run against actual artifacts.

- [ ] Build Windows EXE, MSI, MSIX, and ZIP artifacts where supported by the release design.
- [ ] Build Linux DEB, APT repository, tar.gz, and tar.zst artifacts.
- [ ] Build macOS APP, DMG, and PKG artifacts.
- [ ] Test install, first launch, bridge startup, runtime smoke test, upgrade, and uninstall/cleanup on each target OS.
- [ ] Verify application icon, desktop/start-menu shortcuts, service registration, and uninstall cleanup.
- [ ] Verify Authenticode signing and signature validation for Windows releases.
- [ ] Verify Developer ID signing and notarization for macOS releases.
- [ ] Verify checksums and artifact provenance; use GPG/Ed25519 signatures where configured for Linux distribution.
- [ ] Verify release tags, workflow tag filters, artifact names, and release publication.
- [ ] Verify portable mode separately from installed mode.

## 7. Product feature completion

Status: **PLANNED / PARTIAL**. A GUI control alone is not evidence of backend functionality.

- [ ] Complete fan curves and persistent fan profiles with validated hardware limits.
- [ ] Complete Performance, Balanced, and Quiet profiles with documented platform behavior.
- [ ] Complete Game Mode process detection and reversible policy application.
- [ ] Complete real-time graphs with bounded history and correct missing-data semantics.
- [ ] Implement RGB/ARGB only for explicitly supported devices and protocols.
- [ ] Complete liquid-cooling telemetry/control research before implementing pump or radiator control.
- [ ] Complete laptop battery health, capacity, cycle, and lifespan reporting where OS APIs expose reliable data.
- [ ] Implement anomaly detection with explainable signals, history, and export.
- [ ] Define BSOD Shield scope; avoid claims of preventing all bugchecks or replacing OS recovery.
- [ ] Complete Safe Mode/recovery workflows with tested rollback behavior.
- [ ] Complete hardware compatibility diagnostics based on actual detected capabilities.
- [ ] Complete Pulsar onboarding, tutorial flows, offline TTS, and accessibility behavior.
- [ ] Verify every UI action has a real backend capability or is visibly marked unavailable.

## 8. Documentation and release gates

- [ ] Keep `docs/wiki/` synchronized with actual implementation status.
- [ ] Publish per-platform capability matrices and known limitations.
- [ ] Record test commands, runner OS/architecture, commit SHA, and result for every validation claim.
- [ ] Add a release readiness checklist with explicit evidence links.
- [ ] Do not merge this branch into `main` until required CI passes and the remaining blockers are accepted.
- [ ] Do not describe HWcontrol2.0 as production-ready until build, test, package, install, runtime, hardware, security, signing, integrity, release, and documentation gates are evidenced.

## Current branch snapshot

At the time this roadmap was added:

- Feature branch: `feature/complete-engineering-integration`.
- The branch contains the Stage 7.1/7.2 hardware model, discovery, telemetry attribution, and Linux fan-safety changes.
- The current branch head and CI status must be re-queried before making a verification claim.
- Linux synthetic sysfs tests are not physical hardware validation.
- Windows/macOS identity discovery is not Windows/macOS sensor or fan-actuator support.
- No merge to `main` is authorized by this roadmap.
