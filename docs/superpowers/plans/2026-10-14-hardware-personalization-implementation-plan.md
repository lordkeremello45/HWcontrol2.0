# HWcontrol2.0 — Hardware Personalization Implementation Plan

**Date:** 2026-10-14  
**Design:** [Hardware Personalization and Cross-Platform Device Control](../specs/2026-10-14-hardware-personalization-design.md)  
**Execution policy:** small, testable slices; no feature is advertised as writable until a real adapter and tests prove it.

## Engineering constraints

- Preserve Flutter/Dart → authenticated Go Bridge → native C++/CMake → platform adapter architecture.
- Do not weaken authentication, validation, thermal guards, integrity checks, or CI to make a feature appear functional.
- Keep hardware writes fail-closed. Read-only discovery must remain available where write permissions or a backend are absent.
- No undocumented protocol guessing, arbitrary filesystem paths, hidden input capture, or silent macros.
- Treat Windows, Linux, and macOS separately. Unit/CI evidence is not physical-hardware validation.
- Keep the separate HWcontrol-Security project out of scope unless a direct integration dependency is demonstrated.
- Keep changes on a feature branch and use a pull request; do not push directly to `main`.

## Phase 0 — Baseline and change map

1. Re-read current bridge protocol, hardware metrics/capability types, command validation, fan-control safety gates, profile/settings persistence, localization, and tests.
2. Record current CI workflows and required commands.
3. Run baseline Go tests/build and Flutter analyze/tests where an executable checkout is available; otherwise use CI on the branch and label local execution unavailable.
4. Avoid touching unrelated build/AI dependencies or existing unrelated failures.

**Exit gate:** the affected interfaces and current baseline are understood; existing behavior and known blockers are recorded.

## Phase 1 — Capability contract (first implementation slice)

1. Define a versioned typed capability representation at the Go bridge boundary, with domain, state, platform, backend, optional sanitized device identity, evidence/source, observation time, reason, and optional constraints.
2. Keep compatibility with existing `Get Health` consumers. Prefer additive JSON fields or a new versioned response; do not silently change existing fields.
3. Derive capability state only from real discovered adapters, permission state, valid telemetry, and fresh discovery. Distinguish read-only from writable support.
4. Validate capability IDs, state values, units/ranges, and freshness. Never accept a GUI-provided arbitrary device path as a target.
5. Add table-driven tests for supported/read-only/unavailable/blocked states, missing or stale evidence, malformed constraints, and serialization compatibility.
6. Update the advanced hardware capability wiki only after implementation and tests establish the actual behavior.

**Exit gate:** Go tests pass; old health response fields remain compatible; no new hardware writes are enabled by the capability schema alone.

## Phase 2 — Personalization persistence and UI MVP

1. Map existing settings, UI preferences, fan profiles, game profiles, and migration behavior before adding fields.
2. Add validated settings for accent/theme, dashboard layout/visibility, graph preferences, units, accessibility, and animation/sound. Use existing `HWControlUserDataStore`; avoid a parallel settings store.
3. Add bounded values and defaults for malformed/unknown values. Persistence failure must not block startup.
4. Add unit/widget tests for round-trip persistence, unknown fields, malformed values, migration compatibility, and defaults.
5. Keep UI controls honest: do not expose a control before its state is persisted and restored correctly.

**Exit gate:** preferences survive restart, old configuration remains readable, and corrupt optional preferences do not prevent launch.

## Phase 3 — Profile lifecycle and composition model

1. Define a schema-versioned profile model with stable IDs and explicit feature sections.
2. Implement create, rename, duplicate, delete, import, and export with strict size/schema/range validation.
3. Preserve existing fan/game profile semantics and migrate old profile formats without data loss.
4. Apply profiles by capability: report applied, skipped, and failed settings individually; do not claim full success after partial application.
5. Add rollback for multi-setting operations where rollback is supported; otherwise report the exact partial state.
6. Test duplicate IDs, invalid values, oversized files, unsupported capabilities, partial failure, migration, and round trips.

**Exit gate:** profile operations are deterministic and malformed imports cannot issue hardware commands.

## Phase 4 — Cooling and liquid-cooling discovery (read-only)

1. Define separate models/interfaces for fan, pump, radiator, coolant-temperature, and flow telemetry.
2. Reuse validated platform discovery where available; add no generic fabricated sensor values.
3. Expose explicit source, timestamp, and unavailable reason for each sensor.
4. Add adapter contract tests and fixtures for missing, invalid, stale, and conflicting sensor data.
5. Do not enable pump writes in this phase.

**Exit gate:** supported telemetry is accurately reported; unavailable devices are explicitly marked; no writes are performed.

## Phase 5 — Cooling control (only validated adapters)

1. Implement control only for an adapter with documented control semantics, permissions, safe range, read-back, and failure handling.
2. Require capability freshness and revalidate at the adapter boundary immediately before each write.
3. Preserve thermal floor, critical-temperature emergency behavior, rate limiting, hysteresis, and safe fallback.
4. Require read-back where the hardware/API supports it; report requested vs confirmed state separately.
5. Test rejection paths and simulated adapter faults. Physical validation remains required before a hardware/model combination is marked verified.

**Exit gate:** no control path can bypass bridge and adapter validation; unverified platforms remain read-only/unavailable.

## Phase 6 — RGB/ARGB discovery and control

1. Evaluate dependency and licensing/security implications of candidate backends before adding any dependency.
2. Distinguish 5V addressable ARGB from 12V analog RGB; never infer wiring type from appearance alone.
3. Begin with read-only device/zone discovery and capability reporting.
4. Add writes only through a verified adapter with explicit zones, bounded effects, and read-back or a clear confirmation limitation.
5. Test unsupported devices, adapter errors, stale device lists, and partial multi-zone application.

**Exit gate:** the UI never conflates RGB standards and does not claim a write succeeded without a confirmed adapter result.

## Phase 7 — Keyboard/mouse inventory and safe controls

1. Start with read-only HID inventory and Linux compatibility gaps; separate standard HID capabilities from vendor-specific protocols.
2. Avoid collecting typed content, key sequences, or user activity. Device metadata should be minimized and sanitized.
3. Software pointer speed must not be labeled physical DPI. DPI, polling rate, onboard memory, lighting, and remapping are supported only when an explicit verified device/API capability exists.
4. Any macro feature, if later accepted, must be disabled by default, visibly configured, locally stored, and explicitly user-enabled; no hidden capture.
5. Add permission, device-removal, unsupported-model, and malformed-command tests.

**Exit gate:** inventory works without input capture; controls are individually capability-gated and do not mislabel OS-level settings.

## Phase 8 — Game Mode composition

1. Compose existing Game Mode and game profile features with personalization and only supported device controls.
2. Make application order deterministic and expose per-setting applied/skipped/failed status.
3. Preserve user manual settings and do not force clocks, voltage, overclock, or power-limit writes without a separate validated adapter.
4. Add failure/rollback tests and ensure game exit restores only values HWcontrol changed and can safely restore.

**Exit gate:** Game Mode reports partial outcomes accurately and does not overwrite unrelated user settings.

## Phase 9 — Documentation, packaging, and release validation

1. Update canonical `docs/wiki/` pages to distinguish implemented, partial, unavailable, and planned features.
2. Add a support matrix by OS/backend/feature and list the physical hardware validation still missing.
3. Run Go tests/build, Flutter analyze/tests, CMake/CTest where affected, CI workflows, and package/smoke checks available for each target.
4. Never label Windows/macOS hardware control verified based on Linux tests or mocked unit tests.
5. Review dependency licenses, permissions, privacy, logs, and artifact integrity before release.

**Exit gate:** every claim is backed by code/tests or explicitly marked unverified; no cross-platform or hardware support is implied without evidence.

## Delivery order

Implement only Phase 1 first, then review its diff and test results before expanding into personalization. The remaining phases are ordered dependencies, not a promise that every device/API will be controllable. RGB, pump control, and input controls remain unavailable until their adapters pass their exit gates.

## Current verification status

- Repository source was inspected read-only for existing persistence, fan control, bridge health/capabilities, and tests.
- No product source changes or tests have been run as part of the design/plan authoring step.
- No physical hardware validation has been performed by this plan.
