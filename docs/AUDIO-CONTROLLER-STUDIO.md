# Audio Controller Studio

**Status: PARTIAL / native spectrum plumbing implemented; runtime verification pending.** The native DSP core, miniaudio capture/playback host, persistent control protocol, and Flutter live-control screen are committed to `main`. The host now copies processed stereo samples into a bounded single-producer/single-consumer queue; a dedicated worker performs 1024-point FFT analysis, so FFT work does not run in the real-time audio callback. Spectrum magnitudes, peak frequency, RMS, and sample rate are exposed through the native status JSON and rendered by the Flutter analysis panel. Queue overflow drops an analysis frame rather than blocking audio. Windows, Linux, macOS, and beta workflows stage the helper, but compilation, package/install smoke tests, and physical-device runtime behavior remain unverified. System-audio loopback, virtual microphone/output routing, and application-level routing remain unimplemented.

## Current endpoint enumeration integration

- Flutter sends the authenticated read-only `Get Audio Devices` command.
- The Go bridge locates `hwcontrol_audio_probe` beside itself, in `native/` or `bin/`, or via the absolute `HWCONTROL_AUDIO_PROBE` path.
- The bridge runs one-shot enumeration with a 5-second timeout, validates the JSON and hex-encoded endpoint names, then returns decoded endpoint names. The persistent native control process accepts validated start/stop/status commands and returns metrics; audio samples never cross the bridge.
- Release and beta package workflows now include the native helper beside the bridge. The package/install path is not considered verified until the corresponding CI jobs pass.


## Live DSP session integration

- `Start Audio Studio` accepts a base64url-encoded, HMAC-authenticated profile and validates device indices, finite numeric ranges, and exactly three EQ bands before launching a native session.
- `Stop Audio Studio` and `Get Audio Studio Status` are authenticated bridge actions. Stopping is allowed even when security panic mode is active; starting is not.
- Processed microphone audio is captured and analyzed locally. Output monitoring is off by default; enabling it routes processed mic audio to the selected output and can cause feedback, so headphones are recommended.
- The native host reports peak/RMS/frame metrics plus the latest 1024-point FFT magnitudes and peak frequency. Flutter renders the current spectrum frame (not a scrolling spectrogram history). LUFS, clipping totals, loopback, virtual devices, per-application routing, and packaged-helper lifecycle tests remain outstanding.
- CI compilation and end-to-end device validation are still required; code presence is not proof of runtime success.

## Product goals

A cross-platform audio workstation inside HWcontrol2.0 for microphone processing, system audio, per-application routing where the OS permits it, real-time analysis, profiles, and creator workflows. This is not a claim of feature parity with or superiority over any specific competitor.

## Architecture

- **Flutter/Dart:** profile editor, live meters, native start/stop control, and a current-frame FFT visualizer exist in source. A scrolling spectrogram history, visual routing graph, and latency/dropout measurements remain future work. Capability status must remain explicit.
- **Authenticated Go bridge:** control plane only; device selection, configuration, status, and permissions. Audio buffers must not traverse HTTP/JSON or the bridge.
- **C++17 DSP core:** bounded, allocation-free processing per audio block; float32 samples; interleaved stereo in the first iteration.
- **Platform adapters:** the current device host uses miniaudio's platform backends (WASAPI on Windows, ALSA-compatible devices on Linux, Core Audio on macOS). Capture and playback are implemented as a native prototype; system loopback capture, virtual-device creation, and per-application routing are separate unimplemented capabilities.
- **Safety boundary:** output limiter and finite-sample sanitation; no hidden recording or transmission.

## Initial DSP capabilities

- Three configurable peaking-EQ bands (frequency, gain, Q).
- Input gain, simple noise gate, static-ratio compressor, and peak limiter.
- Input/output peak and RMS meters, clipped-sample count, processed-frame count.
- Fixed-size 1024-point Hann-window FFT spectrum analysis on a worker/analysis thread (not the device callback), with peak-frequency and RMS output.
- Native capture/playback device enumeration and duplex stream lifecycle via pinned miniaudio 0.11.22; monitoring is opt-in to avoid accidental acoustic feedback. Device metrics are published via atomics. The miniaudio stopped-notification callback also clears the public running state when a backend stops unexpectedly (for example, device loss); it never tries to restart or uninitialize a device from the notification callback. A subsequent explicit Start request reinitializes the selected endpoints. Automatic reconnect is not implemented yet. After an unexpected stop, the UI refreshes endpoint enumeration and preserves a prior selection only when an endpoint with the same reported name remains present; missing endpoints are left unselected rather than silently replaced. The user must choose a replacement explicitly. A backend-specific failure reason is not yet exposed.
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
5. Validate the live FFT worker/JSON/UI path on real devices and add spectrogram history, validated LUFS/true-peak and channel/phase analysis.
6. Complete the visual effect graph, profile automation, recording/export, and localization.
7. Add optional microphone calibration and measured-response-aware tuning with explicit consent.
8. Validate package installation, launch, runtime behavior, and cleanup on supported OS versions and physical audio hardware.
## Current branch deliverables

- Dashboard shortcut to Audio Controller Studio.
- Native miniaudio device-host prototype for microphone capture and playback device selection, with a bounded worker-thread FFT path exposed to the Flutter analysis panel.
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