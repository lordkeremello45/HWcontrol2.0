# Audio Controller Studio

**Status: PARTIAL / foundation in progress.** The initial native DSP core and a Flutter profile-editor screen are present on the feature branch. The UI currently saves profile settings locally; it is not connected to live DSP. Device capture, virtual routing, and platform audio backends remain unimplemented.

## Product goals

A cross-platform audio workstation inside HWcontrol2.0 for microphone processing, system audio, per-application routing where the OS permits it, real-time analysis, profiles, and creator workflows. This is not a claim of feature parity with or superiority over any specific competitor.

## Architecture

- **Flutter/Dart:** initial profile editor and presets exist; live meters, visual routing graph, and native control integration remain future work. Capability status must remain explicit.
- **Authenticated Go bridge:** control plane only; device selection, configuration, status, and permissions. Audio buffers must not traverse HTTP/JSON or the bridge.
- **C++17 DSP core:** bounded, allocation-free processing per audio block; float32 samples; interleaved stereo in the first iteration.
- **Platform adapters:** Windows WASAPI, Linux PipeWire (PulseAudio/ALSA fallback as justified), and macOS Core Audio. Capture, processing, and rerouting are separate capabilities and must be reported independently.
- **Safety boundary:** output limiter and finite-sample sanitation; no hidden recording or transmission.

## Initial DSP capabilities

- Three configurable peaking-EQ bands (frequency, gain, Q).
- Input gain, simple noise gate, static-ratio compressor, and peak limiter.
- Input/output peak and RMS meters, clipped-sample count, processed-frame count.
- Fixed-size 1024-point Hann-window FFT spectrum analysis on a worker/analysis thread (not the device callback), with peak-frequency and RMS output.
- Unit tests for limiter bounds, gain, gate behavior, EQ response, compression, FFT peak-frequency detection, non-finite sample sanitation, and invalid sample-rate fallback.

The current gate is a basic threshold gate, not AI noise reduction. The compressor is a simple static curve, not a complete studio compressor with attack/release, knee, and sidechain. The limiter is a hard sample-peak clamp, not a look-ahead true-peak limiter. These distinctions are intentional.

## Required next stages

1. Validate this core in CI with CMake/CTest on Windows, Linux, and macOS.
2. Add smoothed parameters, attack/release envelopes, soft-knee compression, true-peak/look-ahead limiting, de-esser, expander, and a well-tested filter library.
3. Add device lifecycle and capture/playback adapters; test hot-plug, device loss, sample-rate changes, and long-running streams.
4. Add platform-specific system-audio capture and output routing/virtual-device strategy. Do not claim system-wide effects from loopback capture alone.
5. Connect the current FFT analyzer to real input/output taps; then add spectrogram history, validated LUFS/true-peak and channel/phase analysis.
6. Add the Flutter Studio UI, visual effect graph, profile automation, presets, recording/export, and localization.
7. Add offline/opt-in microphone calibration and privacy-preserving local assistance.
8. Validate package install, launch, runtime, and cleanup on actual supported OS versions and hardware.

## Current branch deliverables

- Dashboard shortcut to Audio Controller Studio.
- Locally persisted profile editor with Neutral, Voice, Gaming, and Broadcast starting presets.
- UI tests that assert the live-audio limitation is disclosed and preset selection works.
- Native CTest coverage for limiter bounds, gain, gate, EQ, compressor, non-finite sample sanitation, and invalid sample-rate fallback.

## Real-time constraints

The audio callback must not allocate, block on mutexes, perform disk/network I/O, or log synchronously. Control-to-audio parameter updates should use a bounded lock-free exchange or be applied only at a stopped/reconfigured boundary. UI meter snapshots need a race-free bounded handoff. Device callbacks must never directly call Flutter widget state.

## Acceptance criteria

- No non-finite samples escape the DSP core.
- Unit tests pass under CTest and sanitizer builds where available.
- Measured processing time stays within the configured audio block budget on supported reference systems.
- Device removal/reconnect recovers without crashing or silently switching to an unintended microphone.
- Per-platform capture, processing, and routing capabilities are displayed truthfully.
- No recording, analysis upload, or remote transmission occurs without explicit user consent.
