# Changelog

All notable changes to HWcontrol2.0 are documented here.

The project is currently in the Beta channel. Release-specific details should be kept aligned with the corresponding GitHub release and tag.

## [Unreleased]

### Added
- Read-only battery capacity and charge-state telemetry across platform-specific collectors.
- Healthy Core CPU/GPU thermal-condition assessment with explicit insufficient-data handling.
- Optional read-only liquid-cooling telemetry through an externally installed liquidctl CLI.
- Hardware identity discovery with cached, platform-specific collectors.
- Game Mode process/session detection and local per-game profile assignment.
- Local telemetry history, CSV export, diagnostics and capability reporting.
- Optional local Gemma analysis, Piper TTS integration, CPU benchmark, Audio Controller Studio and offline aim-practice screen.

### Improved
- Capability-gated Linux hwmon fan control with RPM feedback, manual-mode preconditions and PWM readback.
- Smart Fan curve validation, thermal emergency policy and local automation rules.
- Bridge authentication, input validation, diagnostics redaction and release-validation workflows.
- Documentation now distinguishes implemented, partial, unavailable and unverified behavior.

### Limitations
- Windows and macOS fan writes remain unavailable.
- Liquid cooling remains read-only; pump control and leak detection are not implemented.
- Operating-system power-mode automation is not implemented.
- Physical hardware coverage and production signing/notarization must be verified separately.
- C++ Game Core and BSOD Shield are not complete released products; SPARK runtime integration is not yet verified end to end.

## Historical release notes

### [0.2.4] — Beta release line

This entry is retained for historical context only. For the complete v0.2.4 artifact list and release-specific notes, see the [v0.2.4 GitHub Release](https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.2.4). Do not infer current feature status from this release. Do not infer current feature status from the historical v0.2.x release line. See [GitHub Releases](https://github.com/lordkeremello45/HWcontrol2.0/releases) for tag-specific artifacts and notes.

[Unreleased]: https://github.com/lordkeremello45/HWcontrol2.0/compare/v0.2.4...HEAD
