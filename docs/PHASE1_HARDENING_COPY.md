Phase 01 hardening checkpoint

AIEngine lifecycle is now idempotent and partial initialization failures release runtime resources. Native C++ regression tests cover invalid model paths, repeated failed initialization, invalid telemetry, and watchdog timeout/re-arm behavior. Set HWCONTROL_TEST_MODEL to run optional real GGUF inference plus repeated successful initialization testing. Native CI executes CTest on Linux, Windows, and macOS.

HMAC replay resistance remains a Phase 03 security item because changing the signed payload requires a coordinated protocol migration. Hardware-control commands still fail closed without a backend. BSOD Shield remains a watchdog mechanism; snapshot/safe-apply/rollback belong to Phase 06.