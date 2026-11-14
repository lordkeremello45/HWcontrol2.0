# Features

This index reflects the current repository source. A feature being present in source does not mean it is enabled in every package or validated on every device. See [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md) for the consolidated implementation and validation snapshot.

## Monitoring and diagnostics

- [Hardware Monitoring](Features-Hardware-Monitoring.md)
- [CPU & GPU Temperature](Features-CPU-GPU-Temperature.md)
- [Hardware Detection](Features-Hardware-Detection.md)
- [Battery Health and Capacity](Features-Battery-Health.md) — read-only capacity estimate; physical laptop validation pending
- [Real-time Hardware Graphs](Features-Real-time-Hardware-Graphs.md)
- [Telemetry History and Thermal Detection](Features-Telemetry-History.md)
- [Healthy Core](Features-Healthy-Core.md) — thermal-condition indicator, not silicon wear or remaining lifespan
- [Troubleshooting](Troubleshooting.md)

## Cooling and control

- [Fan Curve Editor](Features-Fan-Curve-Editor.md)
- [Advanced Control and Automation](Features-Advanced-Control.md)
- [Performance / Balanced / Quiet](Features-Performance-Balanced-Quiet.md) — application presets, not guaranteed OS power-mode changes
- [Game Mode](Features-Game-Mode.md)
- [Liquid Cooling](Features-Liquid-Cooling.md) — optional read-only liquidctl telemetry; no pump control

## Local assistance and companion tools

- [Local AI Core](Features-AI-Core.md) — optional local Gemma analysis; advisory only
- [Accessibility and Offline Piper TTS](Features-Accessibility-and-Piper-TTS.md) — optional user-installed Piper runtime
- [CPU Benchmark](Features-Benchmark.md) — bounded CPU-only benchmark
- [Audio Controller Studio](../AUDIO-CONTROLLER-STUDIO.md) — microphone/audio processing; system loopback and per-app routing remain unavailable
- [Offline Aim Trainer](../CURRENT-IMPLEMENTATION-STATUS.md#implemented-in-source) — local practice only; no game integration or input injection
- [Extension API](Features-Extension-API.md) — metadata/capability manifest, not arbitrary executable plugins

## Architecture and status

- [Architecture](Architecture.md)
- [Advanced Hardware Capabilities](Advanced-Hardware-Capabilities.md)
- [Roadmap](Roadmap.md)

Do not describe the C++ Game Core as a complete released game engine, BSOD Shield as a complete BSOD prevention product, liquid cooling as controllable, or SPARK as fully integrated into every production command path. Their current boundaries are recorded in the implementation status document.
