# HWVision — Research, architecture and delivery roadmap

**Research baseline:** 2026-11-14  
**Status:** Engineering prototype + first native Game Mode policy slice. Not production-ready.

## 1. Product direction preserved from prior design discussions

HWVision is a companion product in the HWcontrol ecosystem, not a replacement for HWcontrol. It has two related but separately gated tracks:

1. **Game Mode Engine (first priority):** game-session-aware policy orchestration, thermal/power safety, low-contention background workload management and reversible recommendations. The Go Bridge currently detects a limited allow-list of game processes and exposes session state; it is not yet a full optimization engine.
2. **Display / Vision Engine:** adaptive Cinema, Gaming, Everyday and Adaptive modes; display capability discovery; color-managed processing; HDR/EDR; VRR awareness; measurable pixel processing.

The existing Flutter prototype under `hwvision/` is retained as a UI/policy preview. It does not currently process pixels or query native display APIs.

## 2. Research findings

### Windows

- Use DXGI output/swap-chain interfaces for renderer-owned HDR presentation. HDR10 output requires an explicit format/color-space contract; the documented R10G10B10A2 + PQ/BT.2100 path is suitable only under its stated swap-chain conditions.
- Query the active output dynamically. Window movement between displays and changes in advanced-color state invalidate cached capabilities.
- The old Windows Game Mode APIs are deprecated from Windows 10 version 1809. Do not base the product on them.
- Process priority is not a general performance optimization. HIGH can starve normal work; REALTIME can make the system unresponsive. The initial engine therefore does not change game process priority, service state, affinity or system power plans.
- Native display inspection should be read-only. Display mutations require explicit user action, a before/after snapshot and rollback.

### Vulkan / Linux

- Vulkan HDR metadata is swapchain metadata (SMPTE 2086 / CTA 861.3); it is not an image enhancement algorithm.
- Treat presentation support, swapchain color-space support and actual compositor/display path as separate capability checks.
- Linux display support depends on compositor, protocol, kernel DRM/KMS and driver. A GPU advertising HDR support does not prove the active desktop compositor can present HDR.
- Do not require root for read-only inspection. Do not write arbitrary DRM sysfs nodes or alter system services as a shortcut.

### macOS

- Use Metal/EDR APIs. Distinguish potential EDR capability from currently available EDR headroom; they are not interchangeable.
- Keep native rendering and display capability checks inside the macOS adapter. Do not infer HDR support from Apple Silicon model alone.

### NVIDIA compute

- CUDA and TensorRT are optional build-time providers. Keep the CPU reference path available.
- Pin and validate CUDA, TensorRT, driver, GPU architecture and serialized engine compatibility as a single compatibility tuple.
- TensorRT engine plans are not universally portable. Version and compute-capability checks must happen before deserialization.
- Do not bundle proprietary SDK libraries or download SDKs in CI without a licensed, controlled distribution mechanism.

### AMD compute

- ROCm/HIP is an optional provider, not a universal Radeon feature. Validate the exact GPU architecture, OS, kernel and driver against AMD's current compatibility matrix.
- Keep HIP provider code isolated from CUDA/TensorRT. Do not require both vendors' SDKs in one build.
- CPU fallback remains mandatory when ROCm is unavailable.

## 3. Architecture

```text
Flutter UI
   |
Authenticated Go Bridge (localhost; existing HMAC/nonce request-response contract)
   |                         |
Game process/session     Read-only hardware telemetry
   |                         |
HWVision C++17 Policy Core (pure deterministic decisions)
   |                         |
Safe Action Plan / capability-gated provider requests
   |                         |
Platform adapters (later, opt-in, reversible)
   |
HWcontrol hardware-control policy (fan/thermal control remains owned by HWcontrol)

Display track:
Display API adapter -> validated capability snapshot -> color-managed frame graph
 -> CPU reference renderer -> optional CUDA/TensorRT or HIP/ROCm compute backend
 -> DX12/Vulkan/Metal presentation integration
```

## 4. First native Game Mode slice

The C++17 Game Mode policy core is deliberately side-effect-free. It accepts validated game-detection, foreground, power, thermal and telemetry inputs, then emits a bounded plan.

Fail-closed rules:
- Unknown game detection => monitoring only.
- Game not foreground => no game-specific optimization.
- Battery use => Balanced / monitoring unless the user opted in.
- Invalid telemetry or invalid thresholds => no actions.
- Thermal limit reached => Quiet safe mode and disable optional GPU work.
- HWVision yields its own background inference/compute while a game is foregrounded.
- Never set game process priority to HIGH/REALTIME or mutate services.
- Fan profile is a recommendation; HWcontrol retains ownership of hardware actuation.

## 5. Display processing algorithm

The display pipeline must be color-managed and explicitly staged:

1. Identify source transfer function and primaries (e.g. sRGB/BT.709, PQ/BT.2020); unknown source metadata must not be guessed as HDR.
2. Decode transfer function to linear-light working values.
3. Convert to a declared wide-gamut working space using published matrices/white-point adaptation.
4. Apply luminance mapping using measured/validated display limits. Preserve black detail and avoid clipping highlights; keep SDR passthrough as a reference path.
5. Apply optional color/sharpness operations in linear light or in a mathematically defined domain, with bounded parameters.
6. Encode to the output transfer function and output color space.
7. Attach HDR metadata only when the active presentation API supports it and the metadata is truthful.
8. Compare output against deterministic reference patches/images and measure frame-time, latency, clipping and color error.

Do not call SDR-to-HDR expansion lossless. It cannot recover source information that was never present. Do not claim Dolby Vision support without the required licensed technology and certification.

## 6. GPU provider contract

- CPU is the mandatory reference implementation and fallback.
- NVIDIA CUDA/TensorRT and AMD HIP/ROCm providers are independent optional build targets.
- Provider selection requires successful runtime initialization, exact device/vendor match, supported architecture, driver/runtime compatibility and a tested operation.
- No arbitrary DLL/SO/dylib discovery. Use explicit package paths, build-time linking and known vendor installation locations.
- GPU loss, timeout, incompatible engine plan or allocation failure returns a structured error and falls back only when the operation is safe and deterministic.
- Never deserialize untrusted TensorRT engine plans. Treat model and engine files as untrusted inputs; validate size, hash/signature policy and compatibility metadata before loading.

## 7. Verification gates

- Unit tests for policy boundaries, NaN/infinity, stale telemetry, unknown capabilities, battery and thermal overrides.
- CMake C++17 build and CTest on Windows x64, Linux x64 and macOS 14+ Apple Silicon.
- Flutter analyze/test for the UI prototype.
- Native adapter tests must use OS APIs behind injectable interfaces.
- Pixel pipeline needs deterministic reference-image tests, color patch error metrics and frame-time benchmarks.
- CUDA/TensorRT and ROCm CI jobs are separate optional jobs; SDK absence is reported as unavailable, never silently passed as a hardware test.
- Physical GPU/display tests remain UNVERIFIED until run on actual supported devices.

## 8. Official references

- Windows HDR / Advanced Color: https://learn.microsoft.com/en-us/windows/win32/direct3darticles/high-dynamic-range
- Windows display configuration: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-displayconfiggetdeviceinfo
- Windows Game Mode API deprecation: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/gamemode/game-mode-portal
- Windows process priority safety: https://learn.microsoft.com/en-us/windows/desktop/api/processthreadsapi/nf-processthreadsapi-setpriorityclass
- Vulkan HDR metadata: https://registry.khronos.org/VulkanSC/specs/1.0-extensions/man/html/VK_EXT_hdr_metadata.html
- Apple Metal HDR/EDR: https://developer.apple.com/documentation/metal/hdr-content
- Apple EDR capability: https://developer.apple.com/documentation/metal/determining-support-for-edr-values
- CUDA Toolkit: https://docs.nvidia.com/cuda/
- TensorRT prerequisites: https://docs.nvidia.com/deeplearning/tensorrt/latest/installing-tensorrt/prerequisites.html
- TensorRT engine compatibility: https://docs.nvidia.com/deeplearning/tensorrt/11.4.1/inference-library/engine-compatibility.html
- ROCm compatibility: https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html
- HIP: https://rocm.docs.amd.com/projects/HIP/en/latest/what_is_hip.html
- macOS EDR values: https://developer.apple.com/documentation/appkit/nsscreen/maximumpotentialextendeddynamicrangecolorcomponentvalue
