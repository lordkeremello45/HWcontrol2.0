# Audio Controller Studio: Technology Review and Completion Plan

**Review date:** 2026-10-16  
**Repository baseline:** `main` after native audio integration commits on 2026-10-16  
**Status:** Competitor research complete for the first pass; live native control path and package staging are implemented in source, but CI/runtime validation is pending.

## Executive finding

The main branch does **not** currently contain the native `audio_core/` or the Flutter `audio_controller_studio.dart` implementation. Those files exist on `feat/audio-controller-studio-core`, a diverged branch that is 124 commits ahead and 9 commits behind main. Do not merge that branch wholesale: its diff contains many unrelated bridge, hardware, CI, and documentation changes. Port audio-specific changes in small, reviewable units after reconciling dependencies.

The existing main-branch CMake entry point only adds `ai_core`; the Flutter dependency manifest includes `audioplayers`, which is for app-level playback and is not a replacement for a low-latency system audio engine. The canonical status page must not be interpreted as proof that the feature branch implementation is integrated into main.

## Competitor technology review

This review is based on public vendor documentation, not reverse engineering of proprietary internals.

### SteelSeries Sonar

Documented capabilities:
- Separate Game, Chat, Media, Aux, and Microphone streams with independent level/effect controls.
- Per-stream output selection and application-to-stream routing.
- Parametric equalization and presets, including gaming-focused presets.
- Microphone noise reduction, noise gate, compressor, and ClearCast AI noise cancellation.
- Spatial audio and game/chat balance (ChatMix).
- Streamer/submix controls and keyboard shortcuts.

Sources:
- https://steelseries.com/gg/sonar
- https://steelseries.com/gg/sonar-for-streamers
- https://support.steelseries.com/hc/en-us/articles/16954265292173-How-does-Sonar-work
- https://support.steelseries.com/hc/en-us/articles/19318513397261-What-is-drag-drop-app-routing-and-how-does-it-work
- https://support.steelseries.com/hc/en-us/articles/22291026664717-Getting-to-know-your-sonar-settings

Important platform constraint: the public Sonar download page targets Windows 10+. Its routing/virtual-device approach cannot be assumed to work identically on Linux or macOS.

### Logitech G HUB / BLUE VO!CE

Documented capabilities:
- Input gain and microphone EQ.
- Signal-cleanup chain including noise reduction, gate, compressor, de-esser, de-popper, and limiter.
- Voice effects including pitch/formant shifting and reverb/delay.
- Presets and user-created configurations.
- Sample playback/recording for monitoring a processed voice and triggering audio.

Sources:
- https://www.logitechg.com/en-us/software/guides/blue-voice
- https://www.logitechg.com/en-us/discover/technology/blue-voice
- https://support.logi.com/hc/en-us/articles/360054288154-What-is-Blue-VO-CE

Some features depend on supported Logitech hardware/software; HWcontrol must not imply that proprietary Logitech processing or device-only features are available for every microphone.

## HWcontrol2.0 product requirements

### P0 — A trustworthy working audio path
- Enumerate capture/playback endpoints in the interactive user session.
- Open the explicitly selected input and output; never silently change the microphone.
- Process real input buffers through a native DSP chain and send them to the selected output.
- Expose truthful running/error state, input/output peak and RMS meters, clipping count, and sample-rate information.
- Stop and release the device safely on screen close, device removal, app shutdown, and errors.
- Keep audio buffers out of HTTP/JSON and the Go bridge. The bridge is control-plane only.
- Add end-to-end smoke tests with virtual/fake devices where possible and real-device validation on each supported OS.

### P1 — Microphone/creator processing
- Parametric EQ (at least 10 bands eventually; initial 3-band implementation is not feature parity).
- High-pass filter, noise gate, compressor with attack/release/knee, limiter, de-esser, de-popper.
- Noise suppression with a clearly identified algorithm/model and CPU-latency measurements; a simple gate must never be labelled AI noise cancellation.
- A/B profile comparison, bypass per effect, safe presets, and a mic test/record-and-playback workflow with explicit local consent.
- Optional voice effects/sampler only after the base path is stable.

### P1 — Mixer and routing
- Master plus Game, Chat, Media, Aux, and Mic buses.
- Independent gain, mute/solo, output assignment, and per-bus effects.
- Persistent per-application routing where the OS exposes reliable controls.
- Virtual microphone/output devices or documented OS-native alternatives.
- Clear per-platform capability matrix: Windows virtual routing, Linux PipeWire/PulseAudio routing, and macOS Core Audio routing must be implemented and tested independently; endpoint enumeration alone is not routing.

### P2 — Analysis and advanced controls
- Live spectrum and spectrogram fed from actual audio taps.
- LUFS / true-peak metering, channel balance, phase/correlation, and latency reporting only when the implementation is measurement-correct.
- Device-aware local Gemma recommendations based on verified device metadata; every suggestion is advisory, range-validated, reviewable, and opt-in.
- Profile import/export with schema versioning and safe defaults; no remote upload of audio or analysis by default.

## Architecture and real-time safety

- Flutter/Dart owns presentation, user consent, profile editing, and capability status.
- Go bridge owns authenticated control requests and bounded configuration/status messages only.
- Native C++ audio engine owns device streams, DSP, routing, and real-time metrics.
- Platform-specific adapters must be capability-gated and independently tested.
- The device callback must not allocate, block on locks, perform disk/network I/O, or synchronously log. Use bounded lock-free or atomic handoff for controls/meters.
- Validate every numeric parameter for finiteness and range. Sanitize non-finite samples; enforce output safety limits; protect against feedback by keeping microphone monitoring off by default.
- Recording, loopback capture, and any virtual routing must be explicit user actions with visible state and immediate stop controls.
- Treat device names as untrusted strings at protocol/UI boundaries. Do not pass raw audio to Gemma; only send minimal device metadata and the requested use case.

## Porting strategy from the feature branch

1. Reconcile the native audio-core files and CMake dependency changes with current main.
2. Port the Flutter profile editor and tests without overwriting current `main.dart` or user-data storage fixes.
3. Reconcile the device-probe and local Gemma request path with the current Go bridge APIs and security checks.
4. Integrate packaged helper binaries only after Windows, Linux, and macOS package workflows are updated.
5. Run CMake/CTest, Go tests, Flutter analyze/tests, and platform package smoke tests; fix failures rather than skipping them.
6. Only then add system loopback, virtual-device routing, and per-application routing, with explicit per-OS capability reporting.

## Acceptance gates

A release is not “complete” until all applicable gates pass:
- [ ] CMake build and CTest pass on Windows x64, Linux x64, and macOS arm64.
- [ ] Flutter analysis and tests pass.
- [ ] Go bridge tests and authentication/security checks pass.
- [ ] Real capture → DSP → selected playback path works, with bounded latency and no callback allocations/locks.
- [ ] Hot-unplug, device switching, suspend/resume, and invalid sample-rate cases recover safely.
- [ ] Mixer buses and app routing work on each OS where claimed; unsupported paths are visibly marked unavailable.
- [ ] Install/package/launch/uninstall smoke tests include all required native helper binaries.
- [ ] No recording or remote transmission occurs without explicit consent.
- [ ] Documentation and UI status match the actual implementation.

## Decision

Build the reliable capture → process → playback path first. Do not attempt to copy proprietary Sonar/BLUE VO!CE internals or promise “better than Sonar” without repeatable audio-quality, latency, CPU, and usability benchmarks. HWcontrol's differentiator should be cross-platform honesty, local-first operation, device-aware recommendations, transparent processing, and dependable routing.
