# ARGON Audio architecture

**Status: PARTIAL.** Existing native DSP, device-host, analysis and spatialization components are separate code modules. The competitive FPS preset and truthful capability inventory are prototypes; the profile is not yet selectable in Flutter or applied to the live device host.

## Modules

- **DeviceAdapters / AudioDeviceHost** — miniaudio-backed capture/playback endpoint enumeration and stream lifecycle. The current live path is microphone capture to selected playback; system loopback, virtual devices and per-application routing are not implemented.
- **DSPChain / AudioEngine** — native float-stereo processing with configurable EQ bands, high-pass, gate, compressor and limiter. These are processing primitives, not codec decoders.
- **SpatialEngine / SpatialAudioProcessor** — parametric mono point-source to stereo processing with azimuth panning, short interaural delay, simplified far-ear filtering and distance attenuation. It is not a measured HRTF renderer, does not model front/back or elevation, and does not decode 5.1/7.1 or object-based audio.
- **HeadphoneProfiles** — generic use-case presets. The included Competitive FPS profile is a conservative starting point; no specific headset has been measured or calibrated.
- **AudioFormatCapabilities** — explicit inventory of what this module supports, depends on the OS/backend for, or has not integrated. It is not a runtime hardware probe.
- **ProfileManager / Flutter controls** — planned integration for device-specific profiles, persistence, switching, and user EQ. Not yet implemented.

## Capability status

| Capability | Status | Notes |
|---|---|---|
| Float stereo DSP | Native processing | AudioEngine works on interleaved float stereo buffers |
| Endpoint capture/playback | Backend-dependent | Depends on OS, device, permissions and available endpoints |
| Generic Competitive FPS preset | Prototype | Not headset-calibrated; EQ taste is subjective |
| Parametric stereo spatializer | Core only | Not a complete 3D localization solution |
| Measured HRTF | Not implemented | Needs reviewed renderer and appropriately licensed data |
| 5.1/7.1 decoding | Not implemented | No multichannel decoder in this module |
| Dolby Atmos / DTS:X / 360 Reality Audio decoding | Not implemented | Requires appropriate licensed technology/integration |
| System loopback / per-app routing / virtual devices | Not implemented | Separate platform adapters and security review needed |
| Head tracking / personalized HRTF | Not implemented | Requires sensor/device integration and calibration |

## Real-time rules

Audio callbacks must not allocate, block on locks, perform file/network I/O, or invoke UI/bridge code. Until a race-free parameter handoff exists, change processor configurations only while streams are stopped or at a controlled restart boundary. The audio module does not record or transmit samples.

## Validation required

Run CMake/CTest and compiler warnings on supported platforms; add sanitizer tests; integrate profiles behind a control-thread boundary; measure callback CPU/latency and dropout behavior; test with actual gaming headsets; verify the installed application on Windows, Linux and macOS. Do not market the parametric prototype as full HRTF or licensed immersive-audio compatibility.
