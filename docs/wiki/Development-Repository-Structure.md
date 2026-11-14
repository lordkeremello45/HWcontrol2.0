# Repository Structure

The repository is a multi-language desktop application with supporting release, security and documentation tooling.

```text
HWcontrol2.0/
├── .github/                 # CI/CD, security scans, Dependabot and agent guidance
├── ai_core/                 # C++ local AI runtime and tests
├── audio_core/              # C++ audio/DSP library, probe and tests
├── bridge_service/          # Go localhost bridge, telemetry, controls and tests
├── deploy/                  # OS service definitions, installer assets and cleanup
├── docs/                    # Product, architecture, validation, release and wiki docs
│   └── wiki/                 # Canonical version-controlled Wiki source
├── gui_dashboard/           # Flutter/Dart desktop UI, localization and tests
├── hw_game_core/            # Early C++20 graphics backend/render-graph foundation
├── installer/               # Cross-platform installer entry points
├── integrations/            # Feedback form / Apps Script integration
├── lib/                     # Shared supporting libraries and hardware identity helper
├── models/                  # Model metadata (not model weights)
├── scripts/                 # Repository, package, signing and validation scripts
├── security/                # Ada/SPARK, Rust support and local audit tooling
├── tools/                   # Development-only telemetry tooling
├── updates/                 # Update/release metadata
├── website/                 # Astro project website; separately AGPL-3.0-only
├── CMakeLists.txt           # Native C++ build orchestration
├── README.md                # Main project overview
├── CHANGELOG.md             # Current and historical release notes
└── LICENSE                  # Desktop project GPL-3.0
```

## Runtime boundaries

- Flutter/Dart is the desktop user interface.
- Go in bridge_service/ is the current hardware telemetry and supported-control boundary.
- C++/CMake in ai_core/ and audio_core/ provides separate native AI/audio functionality.
- hw_game_core/ is an early standalone graphics/backend foundation, not a complete shipped game engine.
- Ada/SPARK and Rust support code provide selected security-policy/FFI components; complete production-path integration is not verified.
- The C# hardware-identification helper is Windows-only and read-only.

## Generated and external assets

Build output, package staging, caches, and downloaded model weights are not committed as source. Release binaries are published as GitHub Release assets. See the root .gitignore, CMakeLists.txt, package workflows, and [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md).
