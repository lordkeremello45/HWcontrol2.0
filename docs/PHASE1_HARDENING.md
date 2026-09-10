# Phase 01 hardening checkpoint

This document records the stabilization boundary for the Phase 01 hardening branch.

## Included

- AIEngine initialization is idempotent and releases any previous runtime before reinitialization.
- Partial AI initialization failures release model, context, sampler, and llama backend state.
- Non-finite telemetry is rejected before inference.
- Native C++ regression tests cover invalid model paths, repeated failed initialization, invalid telemetry, and BSOD Shield heartbeat timeout/re-arm behavior.
- An optional `HWCONTROL_TEST_MODEL` environment variable enables real GGUF load, inference, and repeated successful initialization testing without committing a large model to the repository.
- Linux, Windows, and macOS native CI jobs execute the CTest regression suite.

## Deliberate boundary

The Bridge command protocol remains compatible with the existing Flutter client. HMAC replay resistance is not introduced in this stabilization patch because changing the signed payload would require a coordinated protocol/version migration; this remains a Security phase item. Current hardware-control commands still fail closed when a control backend is unavailable.

BSOD Shield remains a watchdog/heartbeat mechanism at this stage. Snapshot, safe-apply, rollback, and other recovery actions belong to Phase 06.
