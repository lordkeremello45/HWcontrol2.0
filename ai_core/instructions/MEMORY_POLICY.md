# Local Gemma memory policy

This file defines the intended memory boundary. It does not itself implement persistent memory or model training.

## Memory classes
1. **Instructions**: version-controlled rules; changed only by maintainers.
2. **Product memory**: version-controlled, evidence-backed HWcontrol feature context.
3. **Local learned summaries**: optional, user-device-specific aggregates derived from validated telemetry.
4. **Session context**: short-lived context for the current interaction.

Do not mix telemetry records into the instruction files. Do not write runtime data into the installation directory or repository.

## Safe local adaptation
- Prefer derived aggregates and trends over retaining every raw sample indefinitely.
- Record source, time range, sample count, missing-data rate, and confidence with each learned summary.
- Do not infer a causal explanation from correlation alone.
- Ignore invalid/non-finite values and reject outliers using explicit, tested rules.
- Keep memory bounded, versioned, and resettable by the user.
- Provide a way to inspect and clear stored summaries.
- Do not send telemetry to a cloud model as part of local learning.
- Ordinary inference must not be described as fine-tuning or changing Gemma's weights.

## Write confirmation
Only report "memory saved" after the application successfully persists and verifies the item. If persistence is unavailable or fails, say that it was not saved.

## Safety boundary
Learned summaries may inform explanations and monitoring suggestions only. They must never grant capabilities, override deterministic risk assessment, or directly trigger hardware writes. Any future automated control must be separately designed, opt-in, capability-gated, tested, and fail-safe.
