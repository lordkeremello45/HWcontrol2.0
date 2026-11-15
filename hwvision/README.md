# HWVision

HWVision is an independent C++17 engine and Flutter desktop companion in the HWcontrol ecosystem.

## Priority and status

The first engineering priority is the **Game Mode Engine**. A pure, deterministic C++17 policy core is included under native/. It consumes game-session, foreground, power, thermal and validated telemetry state and emits a bounded policy plan.

The Flutter display companion is an early prototype. Its deterministic policy engine selects bounded Cinema, Gaming, Everyday and Adaptive image parameters, but it does not yet process pixels or query native display APIs.

### HDR10+ status

HDR10+ (SMPTE ST 2094-40 Application #4) is the primary dynamic-HDR format targeted by HWVision; HDR10 remains the static fallback.

**PARTIAL / implemented:**
- C++17 semantic metadata model and validator for Application Version 0/1 constraints.
- Deterministic output-route policy for verified native passthrough, software metadata-driven tone mapping, HDR10 static fallback and SDR fallback.
- Flutter capability model separates HDR10+ metadata, native passthrough, ADVANCED and GAMING states.

**NOT IMPLEMENTED:**
- T.35/SEI/container bitstream extraction and video decoder integration.
- Pixel processing, PQ/BT.2020 color pipeline and actual ST 2094-40 tone mapping.
- Native DXGI/D3D12, Linux DRM/Vulkan or Metal/EDR display adapters.
- Verified HDR10+ passthrough on any physical device.
- HDR10+ ADVANCED/GAMING runtime support or HDR10+ certification.

The validator accepts an already-decoded semantic metadata model; it is not a bitstream parser or a playback implementation. Unknown display capability remains unknown until a native adapter proves it. See [HDR10+ Implementation](docs/HDR10PLUS_IMPLEMENTATION.md).

## Current native Game Mode behavior

- Unknown game detection, non-foreground games and unknown thermal state fail closed to monitoring-only.
- Battery operation is restricted unless explicitly enabled.
- Warm thermal state downgrades Performance to Balanced.
- Critical temperature forces Quiet safe mode and disables optional GPU work.
- HWVision background inference/compute yields while a game is foregrounded.
- It never changes game process priority, system services or fan settings. Fan profile is a recommendation for HWcontrol, which retains hardware-control ownership.

## Build and test

From repository root:

    cmake -S . -B build -DBUILD_TESTING=ON
    cmake --build build --config Release
    ctest --test-dir build --output-on-failure

For the Flutter display prototype:

    cd hwvision
    flutter pub get
    flutter analyze --fatal-infos
    flutter test

## Planned native providers

CPU reference path is mandatory. NVIDIA CUDA/TensorRT and AMD HIP/ROCm will be separate optional providers with explicit SDK/version/driver checks. SDKs are not bundled and no provider is considered ready until a real operation succeeds on compatible hardware.

See [Engine Architecture](docs/ENGINE_ARCHITECTURE.md) and [Research and Roadmap](docs/RESEARCH_AND_ROADMAP.md).
