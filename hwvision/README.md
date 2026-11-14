# HWVision

HWVision is an independent C++17 engine and Flutter desktop companion in the HWcontrol ecosystem.

## Priority and status

The first engineering priority is the **Game Mode Engine**. A pure, deterministic C++17 policy core is now included under `native/`. It consumes game-session, foreground, power, thermal and validated telemetry state and emits a bounded policy plan.

The Flutter display companion is an early prototype. Its deterministic policy engine selects bounded Cinema, Gaming, Everyday and Adaptive image parameters, but it does not yet process pixels or query native display APIs.

## Current native Game Mode behavior

- Unknown game detection, non-foreground games and unknown thermal state fail closed to monitoring-only.
- Battery operation is restricted unless explicitly enabled.
- Warm thermal state downgrades Performance to Balanced.
- Critical temperature forces Quiet safe mode and disables optional GPU work.
- HWVision background inference/compute yields while a game is foregrounded.
- It never changes game process priority, system services or fan settings. Fan profile is a recommendation for HWcontrol, which retains hardware-control ownership.

## Build and test

From repository root:

```sh
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --config Release
ctest --test-dir build --output-on-failure
```

For the Flutter display prototype:

```sh
cd hwvision
flutter pub get
flutter analyze --fatal-infos
flutter test
```

## Planned native providers

CPU reference path is mandatory. NVIDIA CUDA/TensorRT and AMD HIP/ROCm will be separate optional providers with explicit SDK/version/driver checks. SDKs are not bundled and no provider is considered ready until a real operation succeeds on compatible hardware.

See [Engine Architecture](docs/ENGINE_ARCHITECTURE.md) and [Research and Roadmap](docs/RESEARCH_AND_ROADMAP.md).
