# Audio Controller Studio

**Status: PARTIAL — device discovery and local Gemma recommendations are implemented in source; full live audio routing is not yet complete.**

Audio Controller Studio is HWcontrol2.0's planned cross-platform microphone and playback control workspace.

## Implemented in the feature branch

- C++17 DSP foundation: three peaking-EQ bands, gain, threshold gate, high-pass filter, compressor, limiter, RMS/peak metrics, and a fixed-size FFT analyzer.
- Native miniaudio device host prototype for capture/playback endpoint enumeration and local capture processing. Monitoring is opt-in.
- `hwcontrol_audio_probe --json` exposes input/output endpoint names, indices, and default status. It does not prove acoustic frequency response or enumerate every supported format.
- Flutter launches the packaged probe in the interactive user session to enumerate that user's input/output endpoints, then sends bounded, hex-encoded device metadata to the already-running local Gemma process. Audio samples never enter this request path.
- Local Gemma receives device type, endpoint/model label, use case, reported sample rate/channel count, and whether the user verified those specifications.
- Flutter validates Gemma's JSON output against numeric and structural bounds. Recommendations are not applied automatically; the user must explicitly apply the validated settings and save the profile.

## Privacy and safety

- Audio samples are not sent to Gemma or through the Go bridge by the audio-profile recommendation feature. Only device metadata and user-selected use-case information are submitted to the local model.
- No recording or remote upload is performed by this feature.
- Device names and manufacturer labels are untrusted metadata, not instructions.
- Model output is advisory. Invalid or out-of-range JSON is rejected. Recommendations must not be treated as measured frequency response.
- Use a limiter and conservative EQ; do not infer safe listening volume from endpoint names.

## Remaining work

- Verify release packages install `ai_engine` and `hwcontrol_audio_probe` beside the bridge on Windows, Linux, and macOS.
- Run end-to-end CI and package smoke tests; validate on physical audio devices.
- Connect the live DSP controls/meters to the device host, including safe parameter handoff and hot-plug recovery.
- Add platform-specific system-audio loopback, virtual devices, and per-application routing. These are **not implemented** by endpoint enumeration alone.
- Add real device-format capability queries, optional acoustic calibration, and measured-response-aware tuning.
- Validate Gemma output against the schema and approval flow on supported model/runtime combinations.

Do not claim system-wide effects, virtual microphone support, or acoustic calibration until those capabilities are implemented and tested on each platform.
