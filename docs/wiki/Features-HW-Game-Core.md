# HW Game Core

## Status

**PARTIAL — foundation prototype only.** This module is separate from Game Mode and provides a portable C++17 image-scaling contract plus a deterministic CPU bilinear reference implementation and CTest coverage.

It does **not** currently implement an FSR/DLSS-class temporal or ML upscaler, frame generation, Direct3D 12/Vulkan integration, game injection, FPS capture, or a production game runtime. The CPU scaler is a correctness baseline for image buffers, not a claim of visual-quality or FPS improvement.

## Architecture direction

- `HWControl::GameCore` is a standalone native library, not coupled to Game Mode or the Go bridge.
- The initial public contract accepts RGBA8 image views with explicit dimensions and row stride.
- The CPU bilinear path is intended for deterministic tests and as a fallback/reference backend.
- Future GPU backends should be isolated behind a stable interface (initially Direct3D 12 on Windows, with Vulkan considered for broader vendor coverage).
- A genuine temporal upscaler requires per-frame history and, when available, motion vectors, depth, jitter, exposure and disocclusion handling. A universal drop-in for arbitrary games cannot be promised without integration into their render pipelines.

## Build and test

From a configured repository build directory:

```sh
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --target hwcontrol_game_core_tests
ctest --test-dir build --output-on-failure -R hwcontrol_game_core_tests
```

The root project currently fetches llama.cpp and miniaudio, so configuring the full root project may require network access. No build or runtime result should be inferred from this documentation alone.

## Roadmap

1. Validate the portable image contract and CPU reference path.
2. Add image-quality fixtures and repeatable performance benchmarks.
3. Add a GPU backend behind the same contract; validate capability detection and safe fallback.
4. Prototype temporal reconstruction in an owned test renderer before attempting engine integrations.
5. Evaluate frame generation separately with end-to-end latency and visual artifact metrics.
6. Assess licensing and SDK terms before integrating third-party FSR or DLSS components.
