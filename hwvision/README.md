# HWVision

HWVision is an independent C++17 image-processing engine and Flutter desktop companion in the HWcontrol ecosystem.

## Priority and status

The first engineering priority is the **Game Mode Engine**. A pure, deterministic C++17 policy core is included under native/. It consumes game-session, foreground, power, thermal and validated telemetry state and emits a bounded policy plan. It does not yet execute OS or GPU optimization actions.

The native CMake build now discovers optional FFmpeg, OpenColorIO, OpenEXR and Vulkan development packages, plus the native DXGI/D3D12 or Metal system frameworks where applicable. Discovery is non-fatal by default, performs no downloads, and does not claim runtime integration; see [dependency policy](docs/DEPENDENCIES.md). The native layer also contains a first CPU reference color pipeline. It processes explicit RGBA buffers and supports sRGB, BT.709, linear and ST 2084 PQ transfer functions, BT.709/BT.2020 primary conversion, a continuous luminance shoulder, optional output gamut clipping and ordered dithering. It is a low-level reference primitive, not yet integrated with a video decoder, platform display API or Flutter runtime.

### HDR10+ status

HDR10+ (SMPTE ST 2094-40 Application #4) is the primary dynamic-HDR format targeted by HWVision; HDR10 remains the static fallback.

**IMPLEMENTED (foundation):**
- C++17 semantic metadata model and validator for Application Version 0/1 constraints.
- Deterministic output-route policy for verified native passthrough, software metadata-driven tone mapping, HDR10 static fallback and SDR fallback.
- Flutter capability model separates HDR10+ metadata, native passthrough, ADVANCED and GAMING states.
- CPU reference color-processing primitives for transfer functions, BT.709/BT.2020 primary conversion, luminance shoulder, output bounds and ordered dithering.

**NOT IMPLEMENTED:**
- T.35/SEI/container bitstream extraction and video decoder integration (FFmpeg package discovery is wired; decoder adapter is not implemented).
- Per-frame metadata delivery and normative ST 2094-40 rendering.
- Native DXGI/D3D12, Linux DRM/Vulkan or Metal/EDR display adapters (SDK/framework discovery is wired; presentation adapters are not implemented).
- Flutter ↔ native runtime/ABI integration and real display capability discovery.
- CUDA/TensorRT and HIP/ROCm acceleration.
- Verified HDR10+ passthrough on physical devices.
- HDR10+ ADVANCED/GAMING runtime support or HDR10+ certification.

The validator accepts an already-decoded semantic metadata model; it is not a bitstream parser or a playback implementation. Unknown display capability remains unknown until a native adapter proves it. See [HDR10+ Implementation](docs/HDR10PLUS_IMPLEMENTATION.md) and [Engine Architecture](docs/ENGINE_ARCHITECTURE.md).

## Current native Game Mode behavior

- Unknown game detection, non-foreground games and unknown thermal state fail closed to monitoring-only.
- Battery operation is restricted unless explicitly enabled.
- Warm thermal state downgrades Performance to Balanced.
- Critical temperature forces Quiet safe mode and disables optional GPU work.
- HWVision background inference/compute yields while a game is foregrounded.
- It never changes game process priority, system services or fan settings. Fan profile is a recommendation for HWcontrol, which retains hardware-control ownership.

## Build and test

From repository root:

    cmake -S hwvision/native -B build/hwvision -DBUILD_TESTING=ON
    cmake --build build/hwvision --config Release
    ctest --test-dir build/hwvision -C Release --output-on-failure

For the Flutter display prototype:

    cd hwvision
    flutter pub get
    flutter analyze --fatal-infos
    flutter test

## Optional native dependencies\n\nCMake discovers FFmpeg, OpenColorIO, OpenEXR and Vulkan when installed, and detects the platform graphics SDK/framework. These are optional build-time discoveries only; no third-party binaries are downloaded or bundled, and current runtime targets remain dependency-free. See [DEPENDENCIES.md](docs/DEPENDENCIES.md) for switches, licensing and supply-chain requirements.\n\n## Planned native providers

CPU reference path is mandatory. NVIDIA CUDA/TensorRT and AMD HIP/ROCm will be separate optional providers with explicit SDK/version/driver checks. SDKs are not bundled and no provider is considered ready until a real operation succeeds on compatible hardware.
