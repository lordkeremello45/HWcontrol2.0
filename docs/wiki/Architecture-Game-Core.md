# Game Core — Architecture

## Status

**PARTIAL — portable foundation, backend-neutral GPU resource/device contracts and a first Direct3D 12 triangle sample are implemented. Production renderer backends are not implemented.**

This architecture targets Windows 10/11 x64, Linux x64 and macOS 14+ Apple Silicon. Current code provides deterministic backend-selection policy, a backend-neutral render-graph compiler, backend-neutral GPU resource descriptors and device/backend interfaces, and a Windows-only Direct3D 12 triangle sample. The sample creates a Win32 window and D3D12 device/swapchain, compiles a minimal HLSL shader at runtime and submits a synchronized triangle frame. It is an isolated bring-up sample, not yet the production GAL, reusable 2D/3D renderer or cross-platform window layer.

Game Core is an independent native product. It must build and run without HWcontrol2.0, the Go bridge, hardware-monitoring services or the Flutter dashboard. Optional HWcontrol integration may consume Game Core telemetry, but the engine must never require HWcontrol to launch.

## Platform and API policy

| Platform | Primary backend | Secondary backend | Requirements |
|---|---|---|---|
| Windows 10/11 x64 | Direct3D 12 | Vulkan | Both backends target 2D and 3D |
| Linux x64 | Vulkan | — | Loader, driver, surface and required features must be probed |
| macOS 14+ Apple Silicon | Metal | Optional Vulkan portability | Metal is the supported baseline |

Direct3D 12 is Windows-only in this project. Vulkan is the common Windows/Linux API. macOS 14+ uses native Metal as its production baseline. Vulkan-on-macOS may be offered only when a tested portability implementation is installed and reports the required capabilities; it is not a minimum-platform dependency.

Do not make MoltenVK or another Vulkan portability driver the only macOS implementation. The current KosmicKrisp implementation is based on Metal 4 and documents macOS 26 as its minimum, so it cannot satisfy the macOS 14 baseline.

## High-level component map

~~~text
Game Application / Editor
          |
          v
Engine Runtime
  |-- Lifecycle and frame clock
  |-- Input and window adapter
  |-- Scene / Entity-Component data
  |-- Asset and resource registry
  |-- Physics / animation / audio interfaces
          |
          v
Render Submission Interface
          |
          v
Graphics Abstraction Layer (GAL)
  |-- Backend registry and capability policy
  |-- Resource and pipeline contracts
  |-- Render Graph compiler
  |-- Frame and GPU-lifetime tracking
          |
          +----------------------+----------------------+
          |                      |                      |
          v                      v                      v
     Direct3D 12               Vulkan                 Metal
     Windows                   Windows/Linux         macOS
          |                      |                      |
          +----------------------+----------------------+
                                 |
                                 v
                           GPU / Display
~~~

The GAL normalizes resource identity, pipeline descriptions, command submission, capability reporting and lifetime tracking. It must not erase API-specific synchronization or force all platforms into the least-capable common denominator.

## First native rendering milestone: Direct3D 12 triangle

The Windows-only `hw_game_core_dx12_triangle` sample is the first real graphics-device bring-up target.

- Creates a Win32 window and a D3D12 device using the Windows SDK.
- Enumerates DXGI adapters with the Windows 10-compatible `IDXGIFactory1` path and falls back to the default adapter if explicit enumeration does not produce a device.
- Creates a direct command queue, two-buffer flip-discard swapchain, RTV heap, per-frame command allocators, command list and fence.
- Compiles a minimal HLSL vertex/pixel shader with `D3DCompile`, creates a root signature and graphics PSO, and uploads three vertices.
- Records PRESENT → RENDER_TARGET → PRESENT transitions, clears, draws and presents with per-frame fence tracking.
- Links only on Windows against `d3d12`, `dxgi` and `d3dcompiler`; Linux and macOS portable foundation builds do not include Windows headers or libraries.

Build on a Windows machine with the Windows 10/11 SDK and a D3D12-capable GPU:

~~~sh
cmake -S hw_game_core -B build/game-core -DBUILD_TESTING=ON
cmake --build build/game-core --config Release --target hw_game_core_dx12_triangle
./build/game-core/Release/hw_game_core_dx12_triangle.exe
~~~

This milestone is build-validated by the Windows CI job when that job passes. A successful compile is not a GPU runtime test: actual window presentation, driver behavior, debug-layer cleanliness and hardware compatibility still require a Windows machine with a supported GPU. The sample currently uses a fixed swapchain size; resize handling, device-loss recovery, adapter preference policy and robust runtime diagnostics are follow-up work.

## Backend selection algorithm

The current implementation contains a pure policy function. Real backend adapters will probe their environment and report candidate records. The selection function does not load a driver or claim hardware support.

1. Reject an unknown target platform and duplicate backend registrations.
2. Check the requested API against the platform policy.
3. Require a ready probe result; loader, device, initialization or surface failures are not success.
4. Verify required capabilities (2D, 3D and optional compute).
5. For automatic selection, apply platform priority:
   - Windows: Direct3D 12, then Vulkan.
   - Linux: Vulkan.
   - macOS: Metal, then a probed Vulkan portability backend.
6. For an explicit preference, do not silently switch APIs. Fallback is allowed only when the caller opts in.
7. Return the selected API and a reason code; otherwise return a typed failure.

Device enumeration is deliberately separate. A future adapter must report API version, vendor/device identity, queue families, presentation support, feature/extension support, memory budget and driver diagnostics before it can become a ready candidate. The new `device.hpp` and `gpu_types.hpp` define the initial backend-neutral device/resource contract only; they do not implement GPU allocation, command submission or any native backend.

## Render Graph algorithm

A frame is expressed as a directed acyclic graph of passes and resources.

- A resource is either imported (its initial contents are owned outside this graph) or transient (it must be written before first read).
- Every pass declares one access per resource: read, write or read-write.
- Explicit pass dependencies supplement resource hazards.
- The compiler derives read-after-write (RAW), write-after-read (WAR) and write-after-write (WAW) edges.
- A deterministic topological sort produces an execution order. Ready passes are selected by declaration ID so identical input produces identical plans.
- Unknown handles, duplicate declarations, invalid access modes, read-before-write, self-dependencies and cycles invalidate the plan.
- A backend later maps compiled dependencies to API-specific resource transitions, memory barriers, semaphores/fences and queue waits.

The render graph does not yet perform GPU transitions or command recording. A valid graph is a logical dependency plan, not proof that a GPU frame was rendered.

## Frame and data flow

1. The platform adapter pumps window and input events on the platform-required thread.
2. The frame clock computes elapsed time; runtime advances fixed-step simulation and variable-rate presentation independently.
3. Input is normalized into engine events and delivered to the active scene.
4. Scene/ECS updates produce immutable render data for the frame. GPU API objects are not exposed to gameplay components.
5. The renderer declares passes and resource reads/writes to the render graph.
6. The render-graph compiler validates hazards and emits a deterministic schedule.
7. The selected backend records/submits commands, translates logical dependencies to native synchronization and presents.
8. Per-frame completion values retire temporary allocations and deferred-destruction resources only after GPU completion.
9. Profiling records CPU frame time, GPU timestamps, queue wait time, memory use and present timing when exposed by the platform.

~~~text
OS Events
   |
   v
Input Adapter ---> Scene / ECS ---> Simulation
                         |                |
                         +-------> Render Data
                                          |
                                          v
                                  Pass Declarations
                                          |
                                          v
                                      Render Graph
                                          |
                                   Validate + Toposort
                                          |
                                          v
                                  Backend Command Lists
                                          |
                                    Queue Submission
                                          |
                                  Fence / Semaphore Wait
                                          |
                                          v
                                        Present
~~~

## Data ownership and transfer map

| Data | Producer | Owner / lifetime | Consumer | Boundary rule |
|---|---|---|---|---|
| OS/window events | SDL3 or future platform adapter | Platform event pump; copied into engine events | Input system, application lifecycle | Native handles remain inside platform adapters |
| Input state | Input adapter | Engine input frame; valid for one simulation/render frame | Gameplay and editor | Device-specific codes are normalized; raw device details are optional metadata |
| World state | Scene / ECS systems | Scene lifetime; authoritative CPU-side state | Simulation, animation, render extraction | Gameplay components do not store D3D12/Vulkan/Metal objects |
| Render packet | Render extraction stage | Immutable per-frame snapshot | 2D renderer, 3D renderer | Owns stable IDs and CPU-visible values; no backend pointers |
| Resource description | Asset/resource registry | Asset lifetime plus explicit version | Backend resource manager | Logical resource ID maps to per-device native allocation |
| Render pass declarations | Renderer modules | One graph compilation | Render Graph compiler | Reads/writes are declared before scheduling; undeclared use is invalid |
| Render Graph plan | Render Graph compiler | One frame; immutable after compile | Selected backend | Logical dependencies only; backend translates to native barriers/synchronization |
| GPU command buffers | Backend command recorder | Until queue submission/retirement | Native graphics queue | Never exposed outside the backend boundary |
| GPU completion token | Backend queue/fence/semaphore | In-flight frame lifetime | Deferred resource deletion, transient allocators, frame pacing | Memory/descriptor reuse requires proven GPU completion |
| Telemetry/profiling sample | Runtime/backend profiler | Bounded rolling history or exported capture | Editor, diagnostics, optional HWcontrol adapter | Optional, read-only integration; must not block rendering |

Data ownership rules:
- CPU scene state is authoritative; render packets are immutable snapshots, not shared mutable ECS storage.
- Resource IDs are logical handles. Native handles and API-specific layouts are private to backend implementations.
- GPU lifetime is governed by completion tokens, not C++ scope exit or UI/gameplay object lifetime.
- Asset loading/decoding may run on worker threads, but graphics API upload/submission follows backend-specific thread and queue rules.
- Profiling and HWcontrol telemetry are observers. They cannot become a required dependency of the render loop.

## 2D and 3D composition

2D and 3D are separate renderer modules over shared backend device/resource/queue infrastructure. They are not separate engines and do not imply separate GPU devices.

- The 2D renderer owns sprite batching, atlas/texture sampling, orthographic cameras, text and layer ordering.
- The 3D renderer owns mesh submission, depth/stencil, materials, lighting and 3D cameras.
- The render graph composes world-space 2D, 3D opaque/transparent passes, post-processing and screen-space UI.
- A scene may mix 2D and 3D entities. Explicit render-layer and depth policy determines ordering.
- 2D physics and 3D physics remain distinct simulation domains with explicit transform/conversion rules.

## Shader and asset pipeline

HLSL is the shared shader-authoring language candidate. DXC can emit DXIL for Direct3D and SPIR-V for Vulkan, but outputs are not interchangeable. The build pipeline must keep backend-specific compile targets, reflection metadata and descriptor/binding layouts. Metal shader compilation will use a Metal-compatible source or a separately validated HLSL-to-MSL path; DXIL/SPIR-V must never be passed directly to Metal.

Shader packages must record source hash, compiler version, target API/version, entry point, defines, binding layout and reflection metadata. Cache keys include all these values. Build failures and validation warnings must be surfaced; no unrelated shader binary may be silently substituted.

## Platform window and input layer

SDL3 is the preferred evaluation candidate for window lifecycle, events, controllers and native window handles. It supports Vulkan- and Metal-compatible windows and exposes native window properties. Game Core will use SDL3 only as a platform/window/input layer; it will not use SDL_GPU as its renderer, because Game Core owns the DX12/Vulkan/Metal implementations.

The actual SDL3 dependency/version and native surface adapters are deferred to the first window/swapchain milestone. No SDL dependency is added by this portable foundation.

## Memory, threading and synchronization invariants

- Gameplay and scene code cannot destroy a GPU object directly. GPU resources are owned by the resource registry and retired through deferred destruction.
- Every in-flight frame owns a completion token. Descriptor, upload and transient-resource reuse requires completion on the corresponding GPU timeline.
- D3D12 resource states/barriers and queue fences remain explicit.
- Vulkan stage/access masks, layouts, queue ownership, semaphores and fences remain explicit.
- Metal command buffers and resource hazard tracking remain explicit; backend policy cannot pretend Metal synchronization is identical to D3D12 or Vulkan.
- GPU command recording can be parallelized only after resource ownership and per-thread allocator rules are established.
- Device removal, surface loss, out-of-memory and shader/pipeline creation failures must be observable typed errors, not silent fallback.
- Automatic fallback may change API only before device-dependent assets/pipelines are committed, unless an explicit resource-recreation path exists.

## Build and test contract

The hw_game_core CMake project can be built independently without the root repository's llama.cpp/miniaudio FetchContent dependencies:

~~~sh
cmake -S hw_game_core -B build/game-core -DBUILD_TESTING=ON
cmake --build build/game-core --config Release
ctest --test-dir build/game-core -C Release --output-on-failure
~~~

The root project uses C++17 for existing AI/audio targets. Game Core sets C++20 on its own target only; it does not raise or overwrite the root standard.

CI validates the portable foundation on Windows x64, Linux x64 and an Apple Silicon macOS 15 runner with the deployment target pinned to macOS 14. Sanitizer validation is enabled on Linux. The Windows Game Core CI build compiles the DX12 triangle sample when the Windows SDK is available; CI does not execute it on a physical GPU. Linux and macOS validate the portable foundation only. GPU integration tests will be added only when a runner/device capable of exercising the backend is available.

## Current implementation boundary

| Component | Status |
|---|---|
| Backend-selection policy | IMPLEMENTED; probe results supplied by callers |
| Render Graph dependency compiler | IMPLEMENTED; logical graph only |
| Window/input adapter | PLANNED |
| DX12 device, swapchain, 2D and 3D renderers | NOT IMPLEMENTED |
| Vulkan device, surface, 2D and 3D renderers | NOT IMPLEMENTED |
| Metal device, layer, 2D and 3D renderers | NOT IMPLEMENTED |
| Shader compiler/reflection/cache | PLANNED |
| Physics, animation, editor, asset pipeline | PLANNED |
| GPU profiling and hardware smoke tests | NOT IMPLEMENTED |

## References

- Microsoft Direct3D 12 command queues, command lists and resource barriers: https://learn.microsoft.com/windows/win32/direct3d12/command-queues-and-command-lists
- Microsoft Direct3D 12 multi-engine synchronization: https://learn.microsoft.com/windows/win32/direct3d12/user-mode-heap-synchronization
- Khronos Vulkan synchronization guide: https://docs.vulkan.org/guide/latest/synchronization.html
- DXC HLSL to SPIR-V mapping manual: https://github.com/microsoft/DirectXShaderCompiler/blob/main/docs/SPIR-V.rst
- Apple Metal command structure: https://developer.apple.com/documentation/metal/setting-up-a-command-structure
- SDL3 Vulkan surface creation: https://wiki.libsdl.org/SDL3/SDL_Vulkan_CreateSurface
- SDL3 window flags and drawable pixel sizing: https://wiki.libsdl.org/SDL3/SDL_CreateWindow
- Mesa KosmicKrisp platform requirements: https://docs.mesa3d.org/drivers/kosmickrisp.html
