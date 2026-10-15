# Audio Controller Studio

**Status: PARTIAL / foundation in progress.** The native DSP core, a miniaudio-based capture/playback device-host prototype, and a Flutter profile-editor screen are present on the feature branch. The native host can enumerate and open a selected microphone and playback device, process captured samples, expose atomic metrics, and optionally monitor processed audio. The Flutter UI now calls the authenticated Go bridge for endpoint enumeration and for starting/stopping the native capture/DSP session and polling live peak/RMS/frame metrics. The native probe supports a persistent line-based control mode; the GUI passes a bounded, authenticated profile to the bridge, which validates the parameters before forwarding them. The helper still must be present beside the bridge, in a recognized build directory, or configured with an absolute `HWCONTROL_AUDIO_PROBE` path. System-audio loopback, virtual microphone/output routing, and application-level routing remain unimplemented.

## Current endpoint enumeration integration

- Flutter sends the authenticated read-only `Get Audio Devices` command.
- The Go bridge locates `hwcontrol_audio_probe` beside itself, in `native/` or `bin/`, or via the absolute `HWCONTROL_AUDIO_PROBE` path.
- The bridge runs one-shot enumeration with a 5-second timeout, validates the JSON and hex-encoded endpoint names, then returns decoded endpoint names. The persistent native control process accepts validated start/stop/status commands and returns metrics; audio samples never cross the bridge.
- Packaging is not yet wired to place this helper beside the bridge; endpoint detection reports a clear error until the native probe is packaged or explicitly configured.


## Live DSP session integration

- `Start Audio Studio` accepts a base64url-encoded, HMAC-authenticated profile and validates device indices, finite numeric ranges, and exactly three EQ bands before launching a native session.
- `Stop Audio Studio` and `Get Audio Studio Status` are authenticated bridge actions. Stopping is allowed even when security panic mode is active; starting is not.
- Processed microphone audio is captured and analyzed locally. Output monitoring is off by default; enabling it routes processed mic audio to the selected output and can cause feedback, so headphones are recommended.
- The current native host reports peak/RMS and processed-frame metrics. Live FFT/spectrogram, LUFS, clipping totals, loopback, virtual devices, per-application routing, and packaged-helper lifecycle tests remain outstanding.
- CI compilation and end-to-end device validation are still required; code presence is not proof of runtime success.

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
- Flutter launches the packaged `hwcontrol_audio_probe --json` in the interactive user session to enumerate that user's endpoints, then sends only the bounded audio-profile request to the already-running local Gemma process (`ai_engine --stdio`). This avoids trying to enumerate session audio devices from a privileged background service or loading a second model instance.
- Flutter can refresh local input/output endpoint names, select an endpoint, supply a use case and reported sample-rate/channel count, request local Gemma advice, validate the returned JSON schema/ranges, and explicitly apply validated values to the profile editor.
- Device endpoint enumeration reports endpoint name/default status only; it does not yet prove frequency response or expose all hardware-supported formats. Sample rate/channel values are user-reported, and the UI's verified-specification checkbox must be selected only after checking the OS/device settings.
- **Integration status: PARTIAL.** The request path is implemented in source, but packaged sibling binaries/model discovery and end-to-end runtime behavior still require CI/package and real-machine verification. No suggestion is automatically applied.

## Required next stages

1. Validate the native core and audio-profile protocol in CI with CMake/CTest on Windows, Linux, and macOS.
2. Verify release packages install `hwcontrol_audio_probe` and `ai_engine` where the GUI can find them; validate real device discovery and local Gemma inference on each OS.
3. Connect the live DSP controls and meters to the native device host through a stable, bounded interface; test hot-plug, device loss, sample-rate changes, and long-running streams.
4. Add platform-specific system-audio capture, virtual-device strategy, and per-application routing. Do not claim system-wide effects from endpoint enumeration alone.
5. Connect FFT analysis to real input/output taps; then add spectrogram history, validated LUFS/true-peak and channel/phase analysis.
6. Complete the visual effect graph, profile automation, recording/export, and localization.
7. Add optional microphone calibration and measured-response-aware tuning with explicit consent.
8. Validate package installation, launch, runtime behavior, and cleanup on supported OS versions and physical audio hardware.
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
