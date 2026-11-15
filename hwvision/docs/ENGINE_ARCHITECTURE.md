# HWVision Engine Architecture

## Status

Prototype: deterministic Game Mode policy, HDR10+ semantic metadata validation and output-route selection are implemented. A first dependency-free C++17 CPU reference color pipeline is now implemented with sRGB, BT.709, linear and ST 2084 PQ transfer functions; BT.709/BT.2020 primaries conversion; a continuous luminance shoulder; bounded output gamut; alpha preservation; and deterministic 4x4 ordered dithering. This is a reference processing primitive, not yet a production video renderer or an end-to-end HDR10+ playback stack.

Native display adapters, codec integration, T.35/SEI parsing, GPU providers, and Flutter-to-native runtime integration remain unimplemented.

## Data flow

Decoded frame + explicit source color description -> CPU reference pipeline -> output color description -> deterministic pixel buffer.

Future accelerated flow: Flutter / host application -> authenticated Go Bridge contract -> native HWVision engine -> capability-gated CPU/CUDA/TensorRT/HIP provider -> DXGI/D3D12, Vulkan/DRM or Metal/EDR presentation.

HDR10+ metadata flow:

Codec/container adapter (planned) -> bounded T.35/SEI extraction (planned) -> decoded ST 2094-40 model -> semantic validator (implemented) -> metadata-driven renderer (planned) -> native presentation (planned).

## Modules

- Capability adapters (planned): query HDR/advanced-color, HDR10+, color-space and refresh capabilities through documented platform APIs. Missing or failed queries remain unknown, never supported.
- Game Mode policy engine (implemented): deterministic policy for foreground game, power, thermal and telemetry state.
- HDR10+ metadata model and validator (implemented): C++17 semantic model for ST 2094-40 Application #4 versions 0/1. Validates bounded windows, luminance, MaxSCL, AverageMaxRGB, DistributionMaxRGB, FractionBrightPixels, KneePoint, Bezier anchors and version-dependent optional metadata.
- HDR output-route selector (implemented): chooses only among verified native HDR10+ passthrough, software metadata-driven HDR tone mapping, HDR10 static fallback, HDR-to-SDR tone mapping and SDR passthrough. It does not itself render pixels.
- CPU reference color pipeline (implemented, first slice): dependency-free RGBA buffer processing, transfer decode/encode, BT.709/BT.2020 primary conversion through XYZ, continuous luminance shoulder, optional output-gamut clipping and ordered 4x4 quantization dithering. It requires caller-supplied, trustworthy color descriptions and does not parse video formats or metadata.
- ST 2094-40 renderer (planned): consume validated per-frame metadata and implement the normative dynamic mapping semantics against reference vectors. The current CPU pipeline is not yet that renderer.
- GPU providers (planned): CPU remains the reference/fallback. CUDA/TensorRT and HIP/ROCm are independent optional providers with exact runtime/driver/device compatibility checks.
- Measurement harness (partial): deterministic unit tests exist for transfer functions, buffer validation, output bounds and dithering. Golden-image, colorimetric error, HDR reference-pattern and frame-time benchmarks remain planned.
- Native display adapters (planned): DXGI/D3D12, Linux DRM/Vulkan/compositor and macOS Metal/EDR.
- HWcontrol integration (planned): optional read-only telemetry for performance budgeting. Hardware telemetry must not silently change display settings.

## HDR10+ boundaries

- The semantic metadata validator is not a T.35/SEI bitstream parser.
- Native passthrough is never inferred from generic HDR support or an OS enum. It requires verification of the complete source-to-display chain.
- HDR10+ metadata support, native passthrough, HDR10+ ADVANCED and HDR10+ GAMING are separate capability states.
- HDR10+ ADVANCED and GAMING remain unavailable until their separate technical and licensing conditions are validated.
- HDR10 remains the static metadata fallback. SDR remains the baseline path.

## Engineering rules

1. Display peak luminance must come from a trusted source or calibration; EDID can be missing or inaccurate. The input is a policy bound, not proof of calibrated luminance.
2. SDR-to-HDR expansion cannot losslessly recover information absent from the source.
3. Keep the reference rendering path available and make transforms reversible.
4. Use color-managed transforms in a known space with explicit transfer functions and primaries. Arbitrary gamma changes are not color management.
5. Preview and rollback must exist before mutating system settings.
6. Dolby Vision compatibility is not claimed. The goal is an original, measurable processing approach.
7. A policy estimate is not measured GPU utilization. Collect actual frame-time and latency data.
8. Do not claim superiority without reproducible measurements.
9. Treat all bitstream metadata as untrusted input; bound payload sizes, array lengths and numeric ranges before use.
10. Do not claim HDR10+ certification or use certification marks until adopter, testing and trademark terms are confirmed.
11. The CPU reference path defines expected output; accelerated backends must pass the same conformance vectors within documented tolerances.
12. Rendering APIs must not assume that a monitor HDR capability flag proves the active compositor and display path support the requested output.

## Next gates

1. Add published reference vectors and golden-image tests for transfer functions and color-space conversion.
2. Implement bounded T.35/SEI extraction and parser fuzzing.
3. Implement the normative ST 2094-40 mapping using validated per-frame metadata.
4. Implement real display capability adapters one platform at a time.
5. Integrate native frame buffers and the CPU renderer into the desktop app through a versioned ABI.
6. Add optional CUDA/TensorRT and HIP/ROCm backends, each independently tested with CPU fallback.
7. Validate on physical HDR/SDR displays, with reference targets where possible, and measure frame pacing.
8. Verify the full native HDR10+ output path per OS/GPU/display; otherwise keep software tone mapping or fallback.
