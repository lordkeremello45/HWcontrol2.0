# HWVision Engine Architecture

## Status

Prototype: deterministic Game Mode policy, HDR10+ semantic metadata validation and output-route selection are implemented. Pixel processing and native display integration are not implemented. The current HDR10+ validator consumes an already-decoded metadata model; it does not parse T.35/SEI payloads or decode video.

## Data flow

Operating-system adapter (planned) -> validated display limits and user preferences -> HwVisionEngine (implemented) -> bounded parameters and explanation -> pixel-processing backend (planned) -> rendering integration (planned).

HDR10+ metadata flow:

Codec/container adapter (planned) -> bounded T.35/SEI extraction (planned) -> decoded ST 2094-40 model -> semantic validator (implemented) -> output-route policy (implemented) -> tone mapper / native presentation (planned).

## Modules

- Capability adapters (planned): query HDR/advanced-color, HDR10+, color-space and refresh capabilities through documented platform APIs. Missing or failed queries remain unknown, never supported.
- Game Mode policy engine (implemented): deterministic policy for foreground game, power, thermal and telemetry state.
- HDR10+ metadata model and validator (implemented): C++17 semantic model for ST 2094-40 Application #4 versions 0/1. Validates bounded windows, luminance, MaxSCL, AverageMaxRGB, DistributionMaxRGB, FractionBrightPixels, KneePoint, Bezier anchors and version-dependent optional metadata.
- HDR output-route selector (implemented): chooses only among verified native HDR10+ passthrough, software metadata-driven HDR tone mapping, HDR10 static fallback, HDR-to-SDR tone mapping and SDR passthrough. It does not render pixels.
- Pixel backend (planned): consumes validated parameters for color transforms, tone mapping and optional sharpening. It must use a defined color-managed pipeline and avoid applying transforms twice.
- Measurement harness (planned): reference images, known color patches, luminance/error measurements, frame-time and latency profiling, and A/B comparisons against an unmodified baseline.
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

## Next gates

1. Add deterministic tests for transfer functions and color-space conversion.
2. Implement bounded T.35/SEI extraction and parser fuzzing.
3. Prototype a reversible ST 2094-40 tone mapper against reference images and compare with the no-effect baseline.
4. Implement real display capability adapters one platform at a time.
5. Validate on physical HDR/SDR displays, with reference targets where possible, and measure frame pacing.
6. Verify the full native HDR10+ output path per OS/GPU/display; otherwise keep software tone mapping or fallback.
