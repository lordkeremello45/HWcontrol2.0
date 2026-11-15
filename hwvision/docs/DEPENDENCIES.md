# HWVision third-party dependency policy

## Integrated CMake discovery

HWVision now has opt-in-at-build-time (enabled by default, non-fatal) discovery for:

| Dependency | CMake discovery | Intended use | Runtime status |
|---|---|---|---|
| FFmpeg | pkg-config: libavcodec, libavformat, libavutil, libswscale | Decode/container and HDR metadata adapter | NOT IMPLEMENTED |
| OpenColorIO | OpenColorIO CMake config package | Color-management adapter | NOT IMPLEMENTED |
| OpenEXR | OpenEXR CMake config package | HDR reference/test assets | NOT IMPLEMENTED |
| Vulkan | FindVulkan | Linux/Windows GPU backend foundation | NOT IMPLEMENTED |
| DXGI/D3D12 | Windows SDK import libraries | Windows presentation foundation | NOT IMPLEMENTED |
| Metal | Apple system frameworks | macOS presentation foundation | NOT IMPLEMENTED |

The discovery target is `HWVision::OptionalDependencies`. It exports feature definitions only when a dependency is found. Existing CPU-only targets do not link this interface target yet, so the baseline remains dependency-free and deterministic.

## Build modes

Default configure discovers installed packages without downloading them:

```sh
cmake -S hwvision/native -B build/hwvision -DBUILD_TESTING=ON
```

Disable all optional discovery:

```sh
cmake -S hwvision/native -B build/hwvision -DHWVISION_ENABLE_OPTIONAL_DEPENDENCIES=OFF
```

Require every enabled optional package (useful for a dedicated integration runner):

```sh
cmake -S hwvision/native -B build/hwvision -DHWVISION_REQUIRE_OPTIONAL_DEPENDENCIES=ON
```

Individual switches are available: `HWVISION_ENABLE_FFMPEG`, `HWVISION_ENABLE_OPENCOLORIO`, `HWVISION_ENABLE_OPENEXR`, and `HWVISION_ENABLE_VULKAN`.

## Supply-chain and licensing controls

- No FetchContent, arbitrary download script, binary blob, or SDK auto-install is used.
- Pin package versions in the platform package manifests/lockfiles when those are introduced; record exact package versions in release SBOMs.
- FFmpeg builds must be audited for their enabled configuration. Keep GPL/nonfree components disabled unless the project explicitly accepts the resulting licensing obligations. Review LGPL relinking/source-offer obligations for each distributed binary.
- OpenColorIO, OpenEXR and Vulkan licensing and notices must be included in the third-party notices bundle when shipped.
- Do not bundle CUDA, TensorRT, ROCm, Vulkan SDK tooling, or proprietary vendor SDKs by default.
- Scan resolved versions for known vulnerabilities and verify upstream signatures/checksums where provided.

## Important implementation boundary

CMake discovery is not feature implementation. It does not provide decoding, T.35/SEI extraction, ST 2094-40 rendering, GPU compute, display capability detection, or presentation. A feature becomes available only after a real adapter is implemented, tested, and connected to the runtime. The dependency interface target is intentionally not linked into current renderer targets until those adapters consume the APIs.
