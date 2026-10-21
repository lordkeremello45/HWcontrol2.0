# ARGON Spatial Audio Engine

**Status: PARTIAL — native stereo spatialization core and unit tests added; UI/device-stream integration and listening validation are not yet verified.**

## Implemented in this branch

The C++17 SpatialAudioProcessor accepts mono point-source audio and produces interleaved stereo output with equal-power azimuth positioning (strongest lateralization at -90/+90 degrees), a small interaural time difference using fixed-size delay buffers, a simple far-ear high-frequency shadow approximation, distance attenuation, configurable wet mix, finite-sample sanitation, and bounded parameter/sample-rate validation. The process method does not allocate or take locks. The current model does not distinguish front from rear, so it is not full 360-degree localization.

## Limitations

- This is a lightweight parametric binaural approximation, not a measured HRTF renderer or Dolby Atmos/Dolby Headphone decoder.
- Elevation is validated but does not yet select elevation-dependent filters.
- It processes a mono point source; 5.1/7.1 channel-bed decoding and object-based audio are not implemented.
- The existing live audio host is not yet connected to this processor, nor are bridge controls or Flutter controls.
- Head tracking, personalized HRTF calibration, room simulation, system-audio loopback, virtual output, and per-application routing are not implemented.
- CI compilation, sanitizer testing, cross-platform runtime, packaged application, and headphone listening tests remain required.

## Real-time requirements

Keep process allocation-free and lock-free. Keep UI/bridge control traffic away from the audio callback. Update parameters only at a stopped/reconfigured boundary until a race-free parameter handoff is implemented. This module does not record or transmit audio.

## Next stages

1. Run CMake/CTest and fix failures.
2. Add an authenticated bounded bridge schema for enable, azimuth, distance, and wet mix.
3. Integrate into the native playback path without allocation or blocking in callbacks.
4. Expose truthful controls and capability status in Flutter.
5. Test CPU cost, latency, clipping, and listening quality on Windows, Linux, and macOS.
6. Evaluate licensed measured HRTF datasets or a reviewed HRTF library after licensing and packaging review.
