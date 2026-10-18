# ARGON HRTF FIR processing

## Status

**Implemented:** fixed-storage FIR rendering of a mono positional source through separate left/right head-related impulse responses (HRIRs). The processor validates taps, bounds impulse-response gain, sanitizes non-finite samples, and allocates no memory in its processing loop. A single control-thread producer can queue one validated filter update for the next processing block; the audio thread consumes it without locks and crossfades over 128 frames.

**Not implemented:** an HRIR dataset, SOFA file parsing, automatic head/ear calibration, direction-dependent HRIR interpolation, head tracking, object-audio decoding, or connection to system/game audio loopback. This is a reusable native DSP component, not yet a complete end-user spatial-audio feature.

## API contract

- Supply left/right HRIR taps for the intended sample-rate domain.
- Tap count must be between 1 and 256.
- Taps must be finite; each channel's absolute coefficient sum must not exceed 8.
- Call configure only while processing is stopped. For runtime changes, use request_configuration from one control thread; one pending update is allowed at a time.
- The processing thread applies queued filters at a block boundary and crossfades old/new responses over 128 frames.
- process takes mono float frames and emits interleaved stereo float frames.
- Output may exceed [-1, 1] with valid filters. A downstream limiter is required before integer/device conversion.

## Zero-license-cost path

The DSP implementation is original project code. HRIR data is a separate asset with its own copyright and license terms; verify the selected dataset's license and redistribution conditions before bundling it. Until a dataset loader and licensed dataset are included, do not describe this module as a calibrated or measured-HRTF product.

## Validation

The CTest target verifies impulse-response convolution, left/right coefficients, non-finite input containment, rejected configurations, gain bounds, sample-rate validation, and block-boundary profile updates with a bounded crossfade. Real-time callback timing, platform playback, subjective localization quality, and comparisons with commercial spatial-audio products require separate validation.
