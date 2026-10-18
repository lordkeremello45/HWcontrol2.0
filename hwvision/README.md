# HWVision

HWVision is an early, standalone Flutter desktop companion planned for the HWcontrol ecosystem. Its goal is to inspect display capabilities and, where supported by the operating system and display hardware, manage display profiles and color/HDR settings safely.

## Current status

**Prototype / not production-ready.** This scaffold provides the desktop UI and a testable capability model. It does not yet read actual monitor EDID, toggle HDR, change color profiles, adjust brightness, or implement Dolby Vision. UI profile selection is currently local preview state only and does not change operating-system settings.

## Planned platform support

- Windows 10/11 x64: native display capability detection and HDR/Advanced Color integration are next.
- Linux x64: compositor/desktop-environment-aware capability detection; settings APIs vary by Wayland/X11 environment.
- macOS 14+ Apple Silicon: display information and color-profile integration through supported macOS APIs.

No fake HDR, unsupported format claims, or silent display setting changes are acceptable.

## Run

Requires Flutter stable and Dart SDK compatible with Flutter.

```sh
cd hwvision
flutter pub get
flutter analyze
flutter test
flutter run -d windows # or linux / macos on the matching host
```

## Safety contract

1. Report a feature as supported only after querying the platform API.
2. Keep read-only capability inspection separate from settings mutation.
3. Require explicit user action before changing system display settings.
4. Capture previous settings and provide a verified rollback path before enabling mutations.
5. Never describe HDR10 or a generic HDR path as Dolby Vision.
6. Do not require administrator privileges for read-only inspection.

## Roadmap

- [x] Cross-platform Flutter desktop shell
- [x] Honest capability states and profile-preview UI
- [x] Unit tests for capability/feature gating
- [ ] Native Windows HDR/Advanced Color capability adapter
- [ ] Linux and macOS adapters
- [ ] Color profile management with backup/restore
- [ ] Integration tests on real displays
- [ ] Packaging, signing, and release validation
