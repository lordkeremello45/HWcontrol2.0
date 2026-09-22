# Local AI Core

HWcontrol2.0 includes a local large-language-model analysis engine built around Gemma 3 1B GGUF and llama.cpp. The model runs locally; this component does not upload telemetry to a cloud AI service. The selected Gemma 3 1B Instruct Q5_K_M GGUF model is about 851 MB.

## Model lifecycle

The AI model is optional and is not required to complete the base installation. The installer does not download the model. On the first requested AI analysis, the dashboard downloads the model into the platform-specific HWControl user cache.

The model manager uses HTTPS, verifies the exact expected byte count and SHA-256 digest while streaming, writes through a .part file, and only exposes a verified model as the final filename. Failed model downloads do not block the bridge or hardware monitoring. Obsolete Gemma 2B cache files are removed only after the new model is verified.

## Safety architecture

The LLM is not the hardware safety authority. A deterministic risk layer classifies supplied telemetry as normal, izleme, yuksek, kritik or veri-yetersiz before inference. The LLM only explains measured conditions and is prohibited from directing fan-speed, voltage, clock or power-limit changes.

## Telemetry and trends

The AI receives CPU/GPU temperatures and loads, CPU frequency/core information, GPU memory/power/clocks, fan data when available, RAM/disk utilization, Game Mode state, and hardware identity fields supplied by the caller. Missing values remain missing.

The native AI process is persistent during use so the model is loaded once rather than for every request. The GUI requests analysis periodically and manually, while download failures are throttled to avoid repeated network retries.

## Runtime protocol

`ai_engine --stdio` reads one telemetry request per line and returns `OK|<analysis>`. Malformed telemetry is rejected explicitly.

## Current boundary

The Go bridge remains the authoritative hardware/control path. The LLM is an analysis layer only. Universal AMD/Intel/macOS sensor support is not claimed, and unsupported hardware control remains fail-closed.