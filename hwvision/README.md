# HWVision

HWVision is an early Flutter desktop companion planned for the HWcontrol ecosystem. Its goal is an original adaptive image engine for cinema, gaming, and everyday use.

## Current status

Prototype / not production-ready. The deterministic policy engine computes bounded image-processing parameters based on content mode, ambient-light input, declared display limits, and a processing budget. Unit tests cover mode adaptation, capability gating, bounds, and adaptation direction.

This is not yet a pixel-processing implementation. It does not transform rendered frames, read actual monitor EDID, calibrate luminance, toggle OS HDR, change color profiles, or provide Dolby Vision compatibility. Display capability status remains unknown until native adapters are implemented. Profile selection is a local preview only.

See docs/ENGINE_ARCHITECTURE.md for module boundaries and validation gates.

## Run

Requires Flutter stable and Dart SDK compatible with Flutter.

    cd hwvision
    flutter pub get
    flutter analyze --fatal-infos
    flutter test
    flutter run -d windows

Use the matching host target for Linux or macOS.

## Safety contract

1. Do not claim a capability until queried from a trusted platform adapter.
2. Keep capability inspection separate from display-setting mutation.
3. Require explicit user action before system display changes.
4. Make transforms reversible and retain an unmodified reference path.
5. Never describe a generic HDR path as Dolby Vision.
6. Do not require administrator privileges for read-only inspection.
7. Do not advertise superiority until reproducible tests support the claim.
