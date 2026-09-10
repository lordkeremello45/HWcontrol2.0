Phase 01 hardening checkpoint.

AIEngine lifecycle is idempotent; partial initialization is released; invalid telemetry is rejected before inference. Native C++ regression tests cover invalid model paths, repeated failed initialization, invalid telemetry, and BSOD watchdog timeout/re-arm. Set HWCONTROL_TEST_MODEL to enable real GGUF inference and repeated successful initialization testing. Linux, Windows, and macOS native jobs execute CTest.

HMAC replay resistance remains a future security protocol migration. Hardware-control commands continue to fail closed without a backend. BSOD Shield is a watchdog at this phase; snapshot, safe-apply and rollback belong to Phase 06.