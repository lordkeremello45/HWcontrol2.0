# HWcontrol2.0 — Hardware Personalization and Cross-Platform Device Control Design

**Status:** Draft for user review; no product implementation is authorized by this document alone.
**Date:** 2026-10-14
**Repository:** `lordkeremello45/HWcontrol2.0`
**Target branch:** `main` (this design is on a documentation-only review branch)

## 1. Goal

Extend HWcontrol2.0 from hardware monitoring and supported fan control into a cross-platform control center for personalization, cooling, RGB/ARGB, and input devices. The priority is to make features usable where vendor utilities are absent or weak—especially Linux—without claiming capabilities that a device or OS does not provide.

The existing architecture remains:

```
Flutter / Dart GUI
        ↓ authenticated local IPC
Go Bridge
        ↓ validated, capability-gated requests
Native C++ / CMake engine
        ↓ platform/device adapters
OS and hardware interfaces
```

The current repository already has UI preference persistence, theme/animation toggles, profile storage, game profiles, fan curves, per-channel fan profile state, and a bridge hardware capability matrix. This design reuses those foundations rather than replacing them. RGB/ARGB, coolant/pump control, and general keyboard/mouse configuration are not considered implemented until a concrete backend and tests demonstrate them.

## 2. Goals and non-goals

### Goals

- Keep Windows 10/11 x64, Linux x64, and macOS 14+ Apple Silicon as distinct validation targets.
- Represent capabilities as structured data with evidence, platform, device identity, access mode, backend, and a reason when unavailable.
- Make settings/profile persistence versioned, resilient to invalid data, and backward compatible.
- Add software features to supported keyboard/mouse devices when the OS/vendor tool does not offer them, prioritizing Linux compatibility.
- Provide safe, explicit control paths for cooling and lighting; unsupported or failed commands must never appear successful.
- Keep accessibility, privacy, testability, and truthful support documentation as release requirements.

### Non-goals

- Emulating physical capabilities the device does not possess (for example, turning a 1,000 Hz mouse into an 8,000 Hz device).
- Arbitrary firmware flashing, undocumented overclock/voltage writes, bypassing OS permissions, or guessing vendor protocols.
- Global keylogging, collecting typed content, hidden input recording, or running macros without user opt-in.
- Promising every vendor/model/OS combination works. Support is device- and feature-specific.
- Replacing the existing Flutter → Go → C++ architecture or merging the separate HWcontrol-Security project into this scope.

## 3. Capability model

Introduce a shared, typed capability contract at the bridge boundary. Exact field names can be finalized during implementation, but the logical record must include:

- Stable capability identifier and schema version.
- Feature domain: telemetry, cooling, lighting, keyboard, mouse, personalization, or profile.
- State: `supported`, `read-only`, `unavailable`, or `blocked`.
- Platform and backend/adapter identifier.
- Optional device identity (vendor/product IDs and sanitized model label where available).
- Evidence/source, observation timestamp, and a concise reason.
- Control constraints where applicable: units, validated range, step, required permissions, and safe fallback.

Capability state must be computed from the actual adapter and current permissions/device state, not from UI presence or vendor name alone. Stale discovery results must be marked stale or re-queried before writes. A control request is validated twice: at the bridge boundary and in the owning adapter/engine. Every write returns an explicit success/failure result and, where practical, a read-back result. Unsupported writes fail closed.

The GUI renders controls from this capability data. Missing data is not converted to a plausible default value; telemetry shows source and freshness when relevant.

## 4. Feature domains

### 4.1 Personalization and profiles

- Reuse `HWControlUserDataStore` and the existing versioned JSON configuration layout.
- Persist theme mode, accent color, dashboard card visibility/order, graph preferences, units, accessibility preferences, and animation/sound preferences.
- Validate values and provide defaults when a setting is absent or malformed. A preference read/write failure must not prevent startup.
- Preserve current fan and game profile behavior; evolve profile schema through explicit migration.
- Add custom profile create/rename/duplicate/delete and import/export only with schema validation, size limits, and safe defaults.
- Profiles can compose UI preferences, fan settings, and lighting/input settings only when each referenced capability is supported.

### 4.2 Cooling and liquid cooling

- Separate discovery, telemetry, and control interfaces.
- Model fan channels, pumps, radiators, coolant-temperature sensors, and flow sensors independently; devices may expose only a subset.
- Keep CPU/GPU temperature distinct from coolant temperature. Coolant-based curves require a real, valid coolant sensor.
- Record source, unit, timestamp/freshness, and validity for each sensor value.
- Expose pump/fan write controls only through validated platform/device adapters with documented ranges and safe fallback behavior.
- Missing sensors, permissions, adapter timeout, disconnect, invalid readings, or unsupported devices must not trigger invented telemetry or unsafe automatic commands.
- Do not assume a pump can be controlled because its RPM is readable. Do not promise independent control for every AIO/custom loop.

### 4.3 RGB/ARGB Studio

- Use a lighting adapter interface separate from cooling, even if the same physical controller exposes both.
- Discover devices/controllers and their supported zones, colors, effects, brightness, speed, and persistence options.
- Start with capabilities proven by supported backends; solid color and simple effects are preferred before complex effects or synchronization.
- Distinguish motherboard headers and controller/device capabilities. Do not infer electrical compatibility from a marketing label; 5 V addressable RGB and 12 V analog RGB are electrically different and must never be treated as interchangeable outputs.
- Device/firmware-specific effects and onboard memory are exposed only when confirmed by an adapter.
- If OpenRGB or another dependency is evaluated, assess license, packaging, security, supported devices, and whether its API is stable before adoption. No dependency is selected by this design.

### 4.4 Keyboard/mouse compatibility layer

- Identify attached HID devices using OS-supported discovery and expose only identity data that is actually available.
- Separate standard HID behavior from vendor-specific configuration. Generic remapping, macros, DPI, polling rate, RGB, onboard profile storage, and firmware settings are independent capabilities, not one global support flag.
- Prioritize Linux devices for which the manufacturer provides no official configuration tool or poor support, while maintaining platform-specific adapters for Windows and macOS.
- Start with a read-only device inventory and support matrix. Add remapping and macros only after a safe, testable OS-specific design exists.
- Macro execution is opt-in, visible, locally stored, and explicitly user-triggered or bound to a user-configured shortcut. No keystroke-content collection or hidden recording.
- DPI/polling-rate/onboard-memory changes require a verified vendor/device protocol or documented OS/driver API. Software pointer speed is not mislabeled as physical DPI.
- Handle hot-unplug, device replacement, permission denial, and rollback without leaving input in a broken state.

### 4.5 Game Mode integration

Game Mode may select a user-configured profile for supported fan, lighting, and input features. Profile application is transactional where possible: validate all requested changes first, apply only supported settings, report partial application clearly, and preserve a way to restore the previous profile. Sound/animation remains optional and respects accessibility settings. Process detection alone does not imply that a game received CPU/GPU priority or extra memory.

## 5. Security and safety boundaries

- Retain authenticated local IPC and existing integrity checks.
- Treat hardware control as privileged: strict schema/type/range validation, no arbitrary paths or shell interpolation, bounded request sizes/timeouts, and explicit adapter allowlists.
- Never silently elevate privileges or bypass OS permission prompts.
- Do not persist bridge credentials in user profile exports.
- Import files are untrusted input: validate schema, bound size, reject unknown executable payloads, and never auto-run imported macros.
- Avoid storing raw key events. If future remapping needs event handling, collect only the minimum event data necessary for the explicit remapping function and do not log typed content.
- Fail safe on sensor loss, adapter errors, disconnects, and bridge integrity failures. UI must communicate when it cannot confirm a physical action.

## 6. Testing strategy

### Unit tests

- Capability serialization, invalid/missing fields, unknown states, stale records, and feature-specific constraints.
- Preference/profile validation, defaults, schema migration, corrupted JSON, interrupted writes, and import/export bounds.
- Cooling telemetry provenance, missing coolant sensor, invalid units/ranges, pump/fan write rejection, and adapter failures.
- Lighting effect/zone constraints and unsupported device behavior.
- Input-device identity parsing, feature-by-feature capability reporting, macro opt-in, malformed macro import, hot-unplug, and rollback.
- Game profile partial-application reporting and restoration.

### Integration and platform tests

- Go bridge authentication, capability filtering, request validation, timeouts, and honest failure responses.
- Flutter rendering for supported/read-only/unavailable/blocked states and persistence.
- Windows, Linux, and macOS CI builds/tests separately.
- Hardware matrix tests using mock adapters plus physical device tests where hardware is available. Mock tests do not count as physical hardware validation.
- Packaging/install/launch/uninstall checks remain separate from unit tests.

## 7. Delivery phases

The project is too broad to implement as one change. Each phase must have its own reviewed spec/plan, tests, and status report.

1. **Foundation inventory and capability contract:** inspect existing bridge/engine interfaces and tests; define the typed capability contract and adapters' ownership. Avoid product behavior changes until contract tests exist.
2. **Personalization MVP:** accent color, dashboard visibility/order, units and accessibility preferences, persistence/migration, and focused UI tests. Reuse current theme/animation persistence.
3. **Profile schema and composition:** versioned custom profiles with validation and safe import/export; preserve existing fan/game profiles.
4. **Cooling discovery:** normalized fan/pump/sensor inventory and source/freshness metadata, read-only first.
5. **Cooling control:** add only platform/device adapters with documented safe ranges and read-back/failure handling.
6. **RGB/ARGB MVP:** choose and validate an adapter/dependency, implement the first verified device subset, and publish an explicit support matrix.
7. **Input-device inventory MVP:** enumerate devices and publish a feature-level support matrix, prioritizing Linux.
8. **Input controls:** remapping/macros and vendor-specific DPI/polling/RGB only after the inventory and OS permission model pass review.
9. **Game Mode composition:** safely combine already-verified settings and report partial outcomes.
10. **Cross-platform release validation:** packages, smoke tests, physical hardware evidence, documentation and known limitations.

Humor and community features remain intentionally deferred until the core engineering work is stable.

## 8. Acceptance criteria

A feature is not considered implemented merely because a GUI control exists. Before it can be marked VERIFIED:

- Its capability comes from a real adapter/backend.
- Positive and negative paths have automated tests.
- Unsupported hardware, missing permissions, stale telemetry, disconnects, and adapter errors are represented accurately.
- The applicable platform build and tests pass.
- Physical-device claims are backed by actual device testing; otherwise the feature remains UNVERIFIED for that combination.
- Documentation and support matrix match observed behavior.
- No unrelated test is removed or weakened to obtain a passing CI result.

## 9. Known repository observations and limitations

- `gui_dashboard/lib/main.dart` already stores dark mode and animation preference, and loads UI preferences on startup.
- `gui_dashboard/lib/user_data_store.dart` already provides versioned JSON persistence and legacy migration for UI preferences, settings, profiles, and fan curves.
- `bridge_service/src/health.go` exposes capability information and explicit unavailable states for several controls.
- `docs/wiki/Advanced-Hardware-Capabilities.md` documents the current fan-control safety boundaries and says Windows/macOS per-channel fan control is not validated.
- Existing search results did not establish an implemented RGB/ARGB, coolant/pump-control, or generic keyboard/mouse configuration backend. This is a search finding, not proof that no related code exists anywhere in the repository; implementation planning must perform targeted source-tree inspection.
- This design has not been built or tested because it is a design artifact, not product code.
