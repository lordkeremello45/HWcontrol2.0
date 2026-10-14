# Audio Controller Studio

**Status: PARTIAL / foundation in progress.** The native DSP core, a miniaudio-based capture/playback device-host prototype, and a Flutter profile-editor screen are present on the feature branch. The native host can enumerate and open a selected microphone and playback device, process captured samples, expose atomic metrics, and optionally monitor processed audio. The Flutter UI is not connected to this host yet. System-audio loopback, virtual microphone/output routing, and application-level routing remain unimplemented.

## Product goals

A cross-platform audio workstation inside HWcontrol2.0 for microphone processing, system audio, per-application routing where the OS permits it, real-time analysis, profiles, and creator workflows. This is not a claim of feature parity with or superiority over any specific competitor.

## Architecture

- **Flutter/Dart:** initial profile editor and presets exist; live meters, visual routing graph, and native control integration remain future work. Capability status must remain explicit.
- **Authenticated Go bridge:** control plane only; device selection, configuration, status, and permissions. Audio buffers must not traverse HTTP/JSON or the bridge.
- **C++17 DSP core:** bounded, allocation-free processing per audio block; float32 samples; interleaved stereo in the first iteration.
- **Platform adapters:** the current device host uses miniaudio's platform backends (WASAPI on Windows, ALSA-compatible devices on Linux, Core Audio on macOS). Capture and playback are implemented as a native prototype; system loopback capture, virtual-device creation, and per-application routing are separate unimplemented capabilities.
- **Safety boundary:** output limiter and finite-sample sanitation; no hidden recording or transmission.

## Initial DSP capabilities

- Three configurable peaking-EQ bands (frequency, gain, Q).
- Input gain, simple noise gate, static-ratio compressor, and peak limiter.
- Input/output peak and RMS meters, clipped-sample count, processed-frame count.
- Fixed-size 1024-point Hann-window FFT spectrum analysis on a worker/analysis thread (not the device callback), with peak-frequency and RMS output.
- Native capture/playback device enumeration and duplex stream lifecycle via pinned miniaudio 0.11.22; monitoring is opt-in to avoid accidental acoustic feedback. Device metrics are published via atomics.
- Unit tests for limiter bounds, gain, gate behavior, EQ response, compression, FFT peak-frequency detection, non-finite sample sanitation, and invalid sample-rate fallback.

The current gate is a basic threshold gate, not AI noise reduction. The compressor is a simple static curve, not a complete studio compressor with attack/release, knee, and sidechain. The limiter is a hard sample-peak clamp, not a look-ahead true-peak limiter. These distinctions are intentional.

## Device-aware local Gemma advisor

- The AI core exposes a validated audio-profile request and a local Gemma prompt builder for microphone, speaker, headphone, and headset profiles.
- The C++ stdio protocol accepts bounded `AUDIO type=... usage=... rate=... channels=... model_hex=... manufacturer_hex=... verified=...` requests and returns advisory text as `AUDIO_OK|...`. Text labels are hex-encoded at the protocol boundary to prevent delimiter injection.
- The authenticated Go bridge exposes `Get Audio Devices` by invoking the sibling `hwcontrol_audio_probe --json` binary, and `Get Audio Profile` by invoking the sibling `ai_engine --stdio` binary. The payload is HMAC-authenticated; existing commands without payload retain their previous signature format.
- Flutter can refresh local input/output endpoint names, select an endpoint, supply a use case and reported sample-rate/channel count, request local Gemma advice, validate the returned JSON schema/ranges, and explicitly apply validated values to the profile editor.
- Device endpoint enumeration reports endpoint name/default status only; it does not yet prove frequency response or expose all hardware-supported formats. Sample rate/channel values are user-reported, and the UI's verified-specification checkbox must be selected only after checking the OS/device settings.
- **Integration status: PARTIAL.** The request path is implemented in source, but packaged sibling binaries/model discovery and end-to-end runtime behavior still require CI/package and real-machine verification. No suggestion is automatically applied.

## Required next stages

1. Validate this core in CI with CMake/CTest on Windows, Linux, and macOS.
2. Add smoothed parameters, attack/release envelopes, soft-knee compression, true-peak/look-ahead limiting, de-esser, expander, and a well-tested filter library.
3. Verify the packaged `hwcontrol_audio_probe` and `ai_engine` binaries are installed beside the bridge on each OS; test authenticated device enumeration and local Gemma requests, then handle hot-plug/device loss and sample-rate changes.
4. Add platform-specific system-audio capture and output routing/virtual-device strategy. Do not claim system-wide effects from loopback capture alone.
5. Connect the current FFT analyzer to real input/output taps; then add spectrogram history, validated LUFS/true-peak and channel/phase analysis.
6. Add the Flutter Studio UI, visual effect graph, profile automation, presets, recording/export, and localization.
7. Add offline/opt-in microphone calibration and privacy-preserving local assistance.
8. Connect the authenticated Go bridge to the bounded audio-profile protocol and expose detected device capabilities to Flutter; validate model output against a strict schema before presenting it for explicit approval.\n9. Validate package install, launch, runtime, and cleanup on actual supported OS versions and hardware.

## Current branch deliverables

- Dashboard shortcut to Audio Controller Studio.
- Native miniaudio device-host prototype for microphone capture and playback device selection. The host is not yet connected to the Flutter screen.
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
