# Vendor SDK integration status and implementation contract

**Status: PARTIAL.** This document records the current code boundary and staged integration plan. A registry contract is not a vendor SDK adapter and does not mean any vendor feature is active.

## Scope and ownership

| Integration | Owning repository | Runtime/API scope | Current state |
|---|---|---|---|
| NVIDIA DLSS Super Resolution / Frame Generation | HWcontrol2.0 Game Core | NVIDIA Streamline or NGX; D3D12/Vulkan support verified per SDK release | Contract only; adapter not implemented |
| NVIDIA Reflex | HWcontrol2.0 Game Core | Streamline Reflex; D3D12/Vulkan capability-dependent | Contract only; frame markers/runtime not implemented |
| AMD FSR / FidelityFX | HWcontrol2.0 Game Core | AMD FSR SDK; D3D12/Vulkan | Contract only; loader/effect adapter not implemented |
| NVIDIA Nsight Graphics | HWcontrol2.0 developer tooling | External CLI and capture workflow | Contract only; process integration not implemented |
| AMD Radeon GPU Profiler | HWcontrol2.0 developer tooling | Radeon Developer Panel CLI + RGP; D3D12/Vulkan | Contract only; process integration not implemented |
| HWVision CUDA / TensorRT | HWVision repository | NVIDIA CUDA compute + TensorRT inference | Not present in this repository |
| HWVision ROCm | HWVision repository | AMD ROCm/HIP compute | Not present in this repository |

## Security and compatibility rules

- Never infer SDK availability or feature support from PCI vendor ID. Vendor ID is only an identity check.
- SDK discovery/build configuration and per-device runtime capability probing are separate gates.
- A feature is enabled only after expected vendor, API, SDK version, device/driver compatibility and runtime initialization all pass.
- Unknown feature bits, mismatched vendors, unsupported APIs, invalid states and oversized diagnostics fail closed.
- NVIDIA and AMD SDKs remain optional. Portable Game Core must build without either SDK.
- Do not commit vendor SDK binaries, prebuilt DLLs/SOs/dylibs, proprietary headers, private keys or credentials. Obtain SDKs only from official vendor distribution channels and obey license/redistribution terms.
- Native in-process SDK code is trusted code, not a sandbox. Do not implement arbitrary plugin-directory scanning or load arbitrary DLL/SO/dylib files.
- Unsupported features remain disabled and must not silently fall back to a different vendor implementation.

## Implementation stages

1. **Portable contract (current code):** enumerate integration identities/features and validate vendor/API/feature/state/version/diagnostic data. Covered by the hw_game_core_vendor_sdk_contracts test.
2. **Build-time SDK discovery:** add opt-in CMake options and version-pinned SDK package checks. SDK-not-installed is a normal disabled state; explicitly enabled but missing/mismatched SDK must fail configuration.
3. **Native adapters:** implement Streamline DLSS/Reflex and AMD FSR loader/effect adapters against actual render-device/resource/command interfaces. Blocked by the absence of production D3D12/Vulkan devices, command submission and swapchain lifecycle.
4. **Developer tooling:** implement explicit user-triggered discovery and launch of installed Nsight Graphics CLI and Radeon Developer Panel CLI. Resolve executable paths from known installation roots or user configuration; never search arbitrary writable directories. Pass argument arrays without a shell, validate output paths, and record exit code/tool version.
5. **HWVision bridge:** define a versioned, authenticated local IPC contract for AI inference requests and model metadata. CUDA/TensorRT and ROCm providers belong in HWVision, not Game Core. Providers must be independently optional and must never make NVIDIA and AMD dependencies mandatory together.
6. **Validation:** SDK-free CI on Windows/Linux/macOS; SDK-enabled jobs only where licensed official SDKs are securely provisioned; hardware tests on real compatible GPUs. CI compilation is not physical GPU validation.

## Current architectural blockers

Game Core currently has backend selection and a render-graph compiler, backend-neutral resource/device interfaces, and a Windows D3D12 triangle bring-up sample. It does not yet have production D3D12/Vulkan/Metal devices, command queues/buffers, reusable swapchain lifecycle, native GPU resource handles, shader/pipeline creation or a frame scheduler. DLSS/FSR require real render inputs, motion vectors, depth, exposure, jitter, resource lifetime and frame synchronization. Reflex requires correct frame/present markers and integration with the host frame loop. A stub that reports these features as ready would be unsafe and misleading.

## Official upstream references

- NVIDIA Streamline source and integration guide: https://github.com/NVIDIA-RTX/Streamline
- NVIDIA DLSS programming guide: https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md
- NVIDIA Reflex programming guide: https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideReflex.md
- NVIDIA Nsight Graphics CLI: https://docs.nvidia.com/nsight-graphics/UserGuide/launch-application-overview.html
- AMD FSR SDK: https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK
- AMD Radeon GPU Profiler: https://gpuopen.com/rgp/
- AMD Radeon Developer Panel CLI: https://gpuopen.com/manuals/rdp_manual/radeon_developer_panel_cli/
- NVIDIA TensorRT prerequisites: https://docs.nvidia.com/deeplearning/tensorrt/latest/installing-tensorrt/prerequisites.html
- AMD ROCm compatibility and platform support: https://rocm.docs.amd.com/

These references are implementation inputs, not evidence of HWcontrol2.0 support.
