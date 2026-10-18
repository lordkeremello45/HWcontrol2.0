# HWVision Engine Architecture

## Status

Prototype: deterministic policy layer implemented. Pixel processing and native display integration are not implemented. The engine computes bounded parameters from explicit inputs; it does not claim visual improvement until a pixel pipeline and reference-image tests exist.

## Data flow

Operating-system adapter (planned) -> validated display limits and user preferences -> HwVisionEngine (implemented) -> bounded parameters and explanation -> pixel-processing backend (planned) -> rendering integration (planned).

## Modules

- Capability adapters (planned): query HDR/advanced-color, color-space and refresh capabilities through documented platform APIs. Missing or failed queries remain unknown, never supported.
- Policy engine (implemented): maps Cinema, Gaming, Everyday and Adaptive modes to bounded peak-luminance target, shadow lift, highlight roll-off, color intensity and sharpness parameters.
- Safety limits (implemented): clamps user-controlled values; target peak never exceeds the supplied display limit; HDR/wide-color flags follow explicit capability inputs.
- Pixel backend (planned): consumes parameters for color transforms, tone mapping and optional sharpening. It must use a defined color-managed pipeline and avoid applying transforms twice.
- Measurement harness (planned): reference images, known color patches, luminance/error measurements, frame-time and latency profiling, and A/B comparisons against an unmodified baseline.
- HWcontrol integration (planned): optional read-only telemetry for performance budgeting. Hardware telemetry must not silently change display settings.

## Engineering rules

1. Display peak luminance must come from a trusted source or calibration; EDID can be missing or inaccurate. The input is a policy bound, not proof of calibrated luminance.
2. SDR-to-HDR expansion cannot losslessly recover information absent from the source.
3. Keep the reference rendering path available and make transforms reversible.
4. Use color-managed transforms in a known space with explicit transfer functions and primaries. Arbitrary gamma changes are not color management.
5. Preview and rollback must exist before mutating system settings.
6. Dolby Vision compatibility is not claimed. The goal is an original, measurable processing approach.
7. A policy estimate is not measured GPU utilization. Collect actual frame-time and latency data.
8. Do not claim superiority without reproducible measurements.

## Next gates

1. Run Flutter static analysis and unit tests.
2. Add deterministic test vectors for transfer functions and color-space conversion.
3. Prototype a reversible shader against reference images and compare with the no-effect baseline.
4. Implement real display capability adapters one platform at a time.
5. Validate on physical HDR/SDR displays, with reference targets where possible, and measure frame pacing.
