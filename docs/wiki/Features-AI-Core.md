# Local AI Core

HWcontrol2.0 includes a local large-language-model analysis engine built around Gemma 3 1B GGUF and llama.cpp. The model runs locally; this component does not upload telemetry to a cloud AI service. The selected Gemma 3 1B Instruct Q5_K_M GGUF model is about 851 MB.

## Model lifecycle

The AI model is optional and is not required to complete the base installation. The installer presents a Local AI (Gemma 3 1B) checkbox; when selected, the model is downloaded during installation and verified before use. When unselected, the base installation completes without the model and the first explicit Local AI Analysis request can download it later. Telemetry polling never downloads or starts the model.

The model manager uses HTTPS, verifies the exact expected byte count and SHA-256 digest while streaming, writes through a .part file, and only exposes a verified model as the final filename. Failed model downloads do not block the bridge or hardware monitoring. If the cached model is missing or fails its size/SHA-256 validation, the same verified download path is retried and the invalid cache is replaced only after the new file is fully verified. Obsolete Gemma 2B cache files are removed only after the new model is verified.

## Gemma instructions and local memory boundary

The native AI prompt loads the maintained files in `ai_core/instructions/`:
- `SYSTEM.md`: truthfulness, safety, privacy, and response rules.
- `PRODUCT_CONTEXT.md`: versioned feature inventory and explicit non-implemented boundaries.
- `MEMORY_POLICY.md`: design rules for a future persistent local learning memory; this file is policy documentation and is not itself a persistent-memory implementation.

At startup, the engine checks `HWCONTROL_INSTRUCTIONS_DIR`, then known relative instruction directories. The executable resolves an adjacent `instructions/` directory when one is packaged beside it. CMake copies the files next to the native executable and the telemetry test binary. Each file is size-bounded; if a file is missing, a conservative built-in fallback keeps analysis available. This behavior is offline and does not use a cloud model.

Prompt tests assert that the anti-hallucination rules and important product limitations remain present. Update the files and tests together when verified product behavior changes. These files provide context for telemetry explanations; they do not implement repository-wide retrieval, general-purpose feature Q&A, persistent user memory, or model-weight fine-tuning.

## Safety architecture

The LLM is not the hardware safety authority. A deterministic risk layer classifies supplied telemetry as normal, izleme, yuksek, kritik or veri-yetersiz before inference. The LLM only explains measured conditions and is prohibited from directing fan-speed, voltage, clock or power-limit changes.

## Telemetry and trends

The AI receives CPU/GPU temperatures and loads, CPU frequency/core information, GPU memory/power/clocks, fan data when available, RAM/disk utilization, Game Mode state, and hardware identity fields supplied by the caller. Missing values remain missing.

The native AI process is persistent during active use so the model is loaded once rather than for every request. The GUI requests analysis manually; failed downloads are throttled to avoid repeated network retries. The user can clear the local model cache from the AI panel.

## Runtime protocol

`ai_engine --stdio` reads one telemetry request per line and returns `OK|<analysis>`. Malformed telemetry is rejected explicitly.

## Current boundary

The Go bridge remains the authoritative hardware/control path. The LLM is an analysis layer only. Universal AMD/Intel/macOS sensor support is not claimed, and unsupported hardware control remains fail-closed.