# Local AI Core

HWcontrol2.0 includes a local large-language-model analysis engine built around Gemma 3 1B GGUF and llama.cpp. The model runs locally; this component does not upload telemetry to a cloud AI service. The selected Gemma 3 1B Instruct Q5_K_M GGUF model is about 851 MB.

## Model lifecycle

The AI model is optional and is not required to complete the base installation. The installer presents a Local AI (Gemma 3 1B) checkbox; when selected, the model is downloaded during installation and verified before use. When unselected, the base installation completes without the model and the first explicit Local AI Analysis request can download it later. Telemetry polling never downloads or starts the model.

The model manager uses HTTPS, verifies the exact expected byte count and SHA-256 digest while streaming, writes through a .part file, and only exposes a verified model as the final filename. Failed model downloads do not block the bridge or hardware monitoring. If the cached model is missing or fails its size/SHA-256 validation, the same verified download path is retried and the invalid cache is replaced only after the new file is fully verified. Obsolete Gemma 2B cache files are removed only after the new model is verified.

## Product context supplied to Gemma

The telemetry-analysis prompt includes a compact, versioned `HWCONTROL_PRODUCT_CONTEXT` block (currently `v2026-10`). It summarizes the current feature set and, importantly, the limits that must not be presented as implemented: Game Mode does not change process priority; the Performance Mode toggle is not overclocking; generic per-application RAM reservation and universal voltage/clock/power-limit writes are unavailable; macOS power-mode automation is unavailable. It also describes capability-gated fan control, battery-health caveats, and the bridge's authority over hardware capabilities.

This is deliberately embedded in the native prompt, so it works offline and does not depend on the model manager, a network request, or an external context file being packaged. Prompt tests assert that key features and non-implemented boundaries remain present. When product behavior changes, update this context and its tests alongside the relevant feature documentation.

This is a compact product brief for telemetry explanations, **not** repository-wide retrieval or a general-purpose feature Q&A interface. It does not make the model an authority for controls, and it does not prove the described features work on every device.

## Safety architecture

The LLM is not the hardware safety authority. A deterministic risk layer classifies supplied telemetry as normal, izleme, yuksek, kritik or veri-yetersiz before inference. The LLM only explains measured conditions and is prohibited from directing fan-speed, voltage, clock or power-limit changes.

## Telemetry and trends

The AI receives CPU/GPU temperatures and loads, CPU frequency/core information, GPU memory/power/clocks, fan data when available, RAM/disk utilization, Game Mode state, and hardware identity fields supplied by the caller. Missing values remain missing.

The native AI process is persistent during active use so the model is loaded once rather than for every request. The GUI requests analysis manually; failed downloads are throttled to avoid repeated network retries. The user can clear the local model cache from the AI panel.

## Runtime protocol

`ai_engine --stdio` reads one telemetry request per line and returns `OK|<analysis>`. Malformed telemetry is rejected explicitly.

## Current boundary

The Go bridge remains the authoritative hardware/control path. The LLM is an analysis layer only. Universal AMD/Intel/macOS sensor support is not claimed, and unsupported hardware control remains fail-closed.