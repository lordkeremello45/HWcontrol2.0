# ARGON Audio Enhancement and Virtual Output

## Status

**PARTIAL — DSP prototype only.** The native audio core now contains an allocation-free stereo processing block with low-frequency and high-frequency enhancement, output gain, finite-value handling, and a soft limiter. A CTest target covers basic bounds and invalid configuration behavior.

This is not an operating-system virtual audio driver, does not create a selectable system playback device, and is not yet wired into the existing playback/capture graph or ARGON Audio UI. Build and test results must be checked in CI before treating the prototype as verified.

## Intended architecture

```text
Applications / Games
        |
OS virtual playback endpoint (future, platform-specific)
        |
ARGON Audio routing and mixer (future integration)
        |
ARGON DSP engine (current prototype + future effects)
        |
Physical output device via existing audio host
```

The DSP engine is portable C++17 and expects interleaved stereo float PCM. It does not assume a Realtek device. Future device endpoints must be implemented separately for each OS and must use the platform's supported audio-driver framework.

## Driver feasibility and platform boundaries

- **Windows:** a selectable system-wide playback endpoint generally requires a Windows audio driver/APO or a supported virtual-audio-device approach, signed and packaged appropriately. User-mode DSP alone cannot register a system-wide driver endpoint.
- **Linux:** a virtual sink/source can often be provided through PipeWire or PulseAudio integration without writing a kernel driver; device routing and packaging still need validation.
- **macOS:** system-wide virtual audio devices require a Core Audio driver/DriverKit-compatible approach and platform-specific signing/installation constraints. Existing CoreAudio output hosting alone does not create a virtual device.

A virtual endpoint must not be described as available until it can be installed, selected in system sound settings, route real application audio, and cleanly uninstall.

## DSP safety

- Processing is in-place and performs no allocation or locking on the audio callback path.
- Settings are bounded and reject non-finite values.
- Non-finite input samples are replaced with silence.
- The current filters are a simple tonal enhancement prototype, not a calibrated equalizer, spatial audio system, noise suppressor, or objective proof of better sound.
- Subjective and objective listening tests, latency/CPU measurements, clipping tests, and long-duration callback tests are still required.

## Next steps

1. Run native build and CTest in CI and fix any real failures.
2. Add a callback-level integration point to the existing audio host without blocking or allocating on the realtime thread.
3. Add configurable EQ bands, device/profile persistence, bypass and level-matched A/B testing.
4. Implement a separate OS virtual endpoint beginning with Windows or Linux after selecting the primary target.
5. Validate install, device selection, app routing, latency, uninstall and recovery before exposing it as a supported feature.
