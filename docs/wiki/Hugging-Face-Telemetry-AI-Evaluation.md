# Hugging Face Telemetry AI Evaluation

## Status

**RESEARCH / NOT IMPLEMENTED.** This document records a bounded evaluation plan. It does not claim that a Hugging Face model has been integrated, benchmarked on HWcontrol telemetry, or validated on physical hardware.

## Decision

Do not add a Hugging Face model to the production runtime yet. First evaluate whether forecasting residuals detect useful anomalies that the existing deterministic checks miss. Keep current bridge safety evaluation and deterministic thermal checks authoritative.

## Repository findings

- The bridge already evaluates invalid/missing thermal telemetry, CPU/GPU temperature thresholds, fan-stall risk, runtime-integrity failures, storage pressure, and capability availability in `bridge_service/src/health.go`.
- The native AI core already has finite-value validation and deterministic `RiskAssessment` logic in `ai_core/src/telemetry.cpp`.
- The dashboard retains up to 720 telemetry samples at approximately 5-second intervals (about one hour), with local CSV export. See `docs/wiki/Features-Telemetry-History.md`.
- The current optional native LLM runtime uses `llama.cpp` and expects a GGUF Gemma model. Hugging Face forecasting models are not drop-in replacements for that runtime.
- The project is local-first. Telemetry must not be uploaded automatically.

## Candidate for a controlled experiment

**IBM Granite TinyTimeMixer (TTM):** [ibm-granite/granite-timeseries-ttm-r2](https://huggingface.co/ibm-granite/granite-timeseries-ttm-r2)

Hub metadata reviewed on 2026-10-18:
- Task: time-series forecasting (not a hardware anomaly classifier).
- Reported parameter count: approximately 805,000.
- License metadata: Apache-2.0.
- Model files and the exact model-card inference requirements must be checked before implementation.

Why it is worth evaluating: the reported parameter count is small enough to justify a local inference feasibility test. A forecast model could produce expected telemetry values; a separate, calibrated residual detector could then flag sustained deviations. This is a hypothesis, not a demonstrated benefit for CPU/GPU telemetry.

## Why not integrate it directly now?

1. No project-specific, labelled telemetry corpus or baseline benchmark has yet demonstrated a detection improvement.
2. Forecasting output is not inherently an anomaly verdict. Naive residual thresholds can create false alarms when workload, ambient temperature, power policy, drivers, or sampling cadence change.
3. The model's published architecture/runtime format is not the existing GGUF/llama.cpp interface. A production integration may require an additional inference runtime or a verified conversion path, increasing package size, build complexity, platform-specific risk, and maintenance burden.
4. The current deterministic checks are explainable and already cover several high-severity cases. A model must not replace or suppress them.
5. No model output may authorize fan, voltage, clock, power-limit, or other privileged hardware changes.

## Evaluation plan

### Phase 1 — Local data and baseline

- Use synthetic fixtures and user-initiated local CSV exports only; do not upload machine telemetry to the Hub.
- Validate schema, units, timestamps, missing values, non-finite values, sensor-source changes, duplicate/out-of-order samples, and sampling gaps.
- Build deterministic baselines using existing health/anomaly rules and a simple rolling robust baseline (for example, median/MAD) before trying a learned model.
- Create labelled scenarios: normal idle/load transitions, sustained thermal rise, fan stall, sensor dropout, spikes, clock drops under load, and workload changes.

### Phase 2 — Offline model feasibility

- Pin an exact model revision and record its license and artifact hashes.
- Verify input context length, sampling assumptions, output horizon, preprocessing, supported runtime, CPU-only inference time, peak RAM, and package footprint on representative x64 and arm64 environments.
- Compare forecasting-residual detection against the deterministic baseline on held-out fixtures.
- Report precision, recall, false alarms per hour, detection delay, and resource cost. Do not train on the held-out scenarios.

### Phase 3 — Optional shadow mode

Only if Phase 2 demonstrates material benefit:
- Run the model as an optional, local-only, non-blocking advisory/shadow component.
- Never let inference failures stall telemetry collection or the bridge.
- Treat missing/invalid values and model/runtime errors as **unknown**, not healthy.
- Keep critical thresholds, capability gates, runtime-integrity checks, and fail-safe behavior independent of the model.
- Add deterministic replay tests and platform-specific resource budgets before enabling it in a release.

## Acceptance gates

The model is eligible for a later implementation PR only if all of the following are met:

- Reproducible improvement over deterministic baseline on held-out fixtures, with false-positive and detection-delay trade-offs documented.
- No regression in existing Go/C++ tests or the bridge's fail-closed behavior.
- Model artifacts are optional, revision-pinned, hash-verified, and not downloaded implicitly during build/configure.
- Local inference works without network access after installation and does not transmit telemetry.
- CPU-only performance, peak memory, package-size impact, and behavior on Windows x64, Linux x64, and macOS arm64 are measured rather than assumed.
- Third-party license and notices are reviewed before redistribution.

## Current conclusion

**Hugging Face is useful as a model-discovery and research source. A production model dependency is not justified yet.** The next engineering task is to assemble a reproducible local telemetry fixture set and benchmark deterministic/robust baselines. Revisit TTM only if that experiment exposes a measurable gap.
