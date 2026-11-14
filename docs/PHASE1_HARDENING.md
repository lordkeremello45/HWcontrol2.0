# Phase 01 hardening checkpoint

**Historical checkpoint — not the current implementation specification.** This document records the stabilization boundary for the Phase 01 hardening branch. Later bridge protocol and security changes superseded some statements below. For current behavior, use [Current Implementation Status](CURRENT-IMPLEMENTATION-STATUS.md) and [Application Architecture](wiki/Architecture-Application.md).

## Included

- AIEngine initialization is idempotent and releases any previous runtime before reinitialization.
- Partial AI initialization failures release model, context, sampler, and llama backend state.
- Non-finite telemetry is rejected before inference.
- Native C++ regression tests cover invalid model paths, repeated failed initialization, invalid telemetry, and BSOD Shield heartbeat timeout/re-arm behavior.
- An optional `HWCONTROL_TEST_MODEL` environment variable enables real GGUF load, inference, and repeated successful initialization testing without committing a large model to the repository.
- Linux, Windows, and macOS native CI jobs execute the CTest regression suite.

## Deliberate boundary

At the time of this historical checkpoint, HMAC replay resistance was not introduced in that stabilization patch. The current Go bridge protocol has since added authenticated timestamp/nonce handling and replay checks; see the current application architecture and bridge implementation. Current hardware-control commands still fail closed when a control backend is unavailable.

BSOD Shield remains a watchdog/heartbeat mechanism at this stage. Snapshot, safe-apply, rollback, and other recovery actions belong to Phase 06.
