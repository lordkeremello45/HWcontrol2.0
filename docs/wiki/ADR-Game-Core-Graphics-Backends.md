# ADR: Game Core graphics backend strategy

- **Status:** Accepted for the initial engine architecture
- **Date:** 2026-11-13
- **Scope:** Game Core only

## Decision

Build one engine with one 2D renderer module, one 3D renderer module and platform-specific graphics backends:

- Windows 10/11 x64: Direct3D 12 preferred; Vulkan as the alternative.
- Linux x64: Vulkan.
- macOS 14+ Apple Silicon: native Metal as the supported baseline. Vulkan portability is optional and must be capability-probed and physically tested.

2D and 3D renderers share backend device, resource, queue and render-graph infrastructure. They remain separate renderer modules because their submission, batching, depth and ordering requirements differ.

## Why

- Direct3D 12 is Windows-only and provides explicit command queue/list, resource-state and fence control.
- Vulkan provides a common explicit API for Windows and Linux, but application code must own synchronization and validation.
- Metal is the native macOS API and avoids making the macOS 14 baseline depend on an external Vulkan portability stack.
- A native abstraction shares concepts without pretending resource states, barriers, descriptor models or synchronization primitives are identical.

## Rejected alternatives

### Three independent renderers with duplicated device/resource systems

Rejected because this duplicates resource ownership, memory tracking, synchronization and testing. The chosen design has separate 2D/3D renderer modules and one backend adapter per API.

### Vulkan-only macOS baseline

Rejected because Vulkan is not a native macOS API and requires a portability implementation. The current KosmicKrisp path requires Metal 4/macOS 26, newer than the product's macOS 14 minimum.

### SDL_GPU as the engine renderer

Rejected because Game Core must own the Direct3D 12, Vulkan and Metal implementations and their native capabilities. SDL3 remains a candidate for window/input/native-window integration only.

## Backend selection contract

- Backend probing and backend selection are separate responsibilities.
- A probe reports API readiness, loader/device/surface errors and capabilities.
- Automatic selection uses platform priority.
- Explicit user/API preferences are strict unless fallback was explicitly enabled.
- The selected backend must satisfy requested 2D/3D/compute capabilities.
- The engine never labels a backend ready merely because its SDK headers were found at build time.

## Shader policy

Use DXC as the HLSL compiler candidate. Compile separate DXIL and SPIR-V targets and validate target-specific bindings/reflection. Metal compilation needs its own validated toolchain. No cross-API binary reuse is assumed.

## Consequences

- The portable Game Core foundation can be tested on all target OSes without GPU SDKs.
- The first real graphics milestone must include native device creation, swapchain/surface lifecycle, resource lifetime and debug validation before advanced rendering features.
- macOS support includes a native Metal backend milestone; it is not complete merely because the portable core builds on macOS.
