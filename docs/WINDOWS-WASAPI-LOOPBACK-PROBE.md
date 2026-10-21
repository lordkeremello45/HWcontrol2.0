# Windows WASAPI loopback isolation probe

**Status: prototype added; Windows build and physical-device runtime are not yet verified.**

## Purpose

This deliberately isolates one question: can the default Windows playback endpoint be captured using WASAPI loopback and passed through the existing native C++ DSP engine?

It adds the Windows-only CMake target `hwcontrol_windows_wasapi_loopback_probe`. The tool captures the default render endpoint with miniaudio's `ma_device_type_loopback`, copies each bounded block into fixed storage, runs the existing `AudioEngine`, and reports captured/processed frame counts, input/output RMS and peak, and non-finite sample count. The processor's conservative de-clicker is enabled by default: it uses one frame of look-ahead (about 20.8 microseconds at 48 kHz) to replace isolated high-amplitude single-frame impulses with local interpolation. The same DSP option is available to microphone processing through `ProcessorConfig`.

## Run

From a Windows developer shell after configuring and building the project:

```powershell
cmake -S . -B build -DBUILD_TESTING=ON
cmake --build build --config Release --target hwcontrol_windows_wasapi_loopback_probe
.uildaudio_coreReleasehwcontrol_windows_wasapi_loopback_probe.exe
```

Depending on the generator, the executable may be under a different build subdirectory. Play audio in another application and check that `frames_last_second` increases and the RMS/peak values respond. Press Enter to stop.

## Click/crackle mitigation limits

- `ProcessorConfig::deClickEnabled` defaults to `true`; `deClickThreshold` defaults to `0.18` in normalized float amplitude and is clamped to `0.01..1.0`.
- This is a narrow transient de-clicker, not a general noise-removal or audio repair system. It can reduce isolated digital spikes; it cannot fix driver buffer underruns, bad cables/ground loops, electrical interference, a noisy microphone preamp, or distortion already clipped by the input device.
- The one-frame look-ahead adds one sample of latency and the final pending sample is not flushed when a stream stops. Validate on speech, music, and game transients before release; provide a user setting if it audibly dulls attacks.

## Scope and safety

- Captures the default render endpoint; it does not implement per-application capture.
- Runs the existing native DSP core on captured samples.
- Does not write audio to disk, transmit samples, create a virtual device, or replace/reroute system playback.
- This is a diagnostic probe, not a product feature and not evidence that system-wide effects are implemented.
- WASAPI loopback is Windows-specific. Linux/PipeWire and macOS/Core Audio need separate adapters.
- Do not integrate this into the GUI or advertise it as verified until the Windows build and real-device smoke test pass.

## Validation required

1. Build the new target with the repository's pinned miniaudio 0.11.22 dependency on Windows.
2. Play a known tone or media stream and confirm frame counts increase and RMS/peak become non-zero.
3. Stop playback and confirm measured levels fall near the endpoint's actual idle/noise floor.
4. Check stop/start and default-device changes for crashes or hangs.
5. Measure callback budget and dropout behavior on real hardware.
6. Only after capture is validated, design the separate processed-playback output route. Loopback capture alone cannot modify the sound heard by applications.
