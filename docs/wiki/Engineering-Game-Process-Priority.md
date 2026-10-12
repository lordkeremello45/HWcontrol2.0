# Game Process Priority — Phase 5 Engineering Plan

**Status: DESIGN REVIEW COMPLETE; PROCESS-PRIORITY CHANGES NOT IMPLEMENTED**

This phase must not turn Game Mode's process-detection result into an unqualified process-priority write. The current bridge authenticates commands, but its command envelope signs only action, numeric value, timestamp, and nonce. It does not bind a process target or process-instance identity to the authenticated request.

## Current verified behavior

- The bridge detects one process whose executable basename is on the built-in allow-list or the opt-in `HWCONTROL_GAME_PROCESSES` list.
- The authenticated bridge reports the detected executable name and PID.
- Game Mode can be enabled for detection/monitoring and profile-based fan-target behavior where a verified fan-control backend exists.
- The bridge does not currently change process priority.

## Security and correctness blockers

1. **PID reuse:** a PID can exit and be reassigned between detection and a priority operation. A PID alone is not a stable process identity.
2. **Target binding:** the current HMAC payload does not include a target PID, process creation time, or executable identity. Adding an unsigned target field would let a request be altered without invalidating the signature.
3. **Platform semantics:** Windows priority classes, Linux nice values, and macOS scheduling behavior are not equivalent. A single numeric value must not imply the same effect on every OS.
4. **Permissions:** increasing scheduling priority may require privileges or be rejected by OS policy. The app must never request administrator/root escalation implicitly.
5. **Restore ownership:** restoration must only touch a process instance that HWcontrol changed, and only if its priority still equals the value HWcontrol applied. User or OS changes must win.
6. **Lifecycle:** game exit, process restart, bridge shutdown, application shutdown, and sleep/resume need explicit behavior. In-memory rollback alone cannot guarantee restoration after a crash.
7. **User consent:** process-priority changes must be an explicit opt-in, not a silent side effect of merely enabling game detection.

## Required implementation sequence

1. Extend the command protocol with an optional, typed process target (PID plus process creation timestamp and normalized executable identity). Include every target field in the canonical HMAC payload on both Go and Dart sides. Existing commands must use the same canonicalization and remain compatible.
2. Resolve the target in the bridge from a fresh process snapshot. Re-check executable identity and creation time immediately before changing priority; reject stale or mismatched targets.
3. Implement separate platform adapters. Each adapter must report capability, prior state, applied state, and read-back result. Unsupported platforms return an explicit unsupported result.
4. Begin with a conservative, documented priority level; never use Windows REALTIME priority. Do not use shell commands with interpolated user input or silently elevate privileges.
5. Track the original and applied priority against the process instance. Restore only when the process identity still matches and current priority still equals the value HWcontrol set.
6. Add unit tests for HMAC tampering, missing/stale target identity, PID reuse, allow-list rejection, unsupported platforms, permission errors, failed read-back, and conditional rollback.
7. Add platform CI compile tests and real OS smoke tests before marking any adapter as runtime-verified.

## Acceptance criteria

- No process-priority write is possible from an unsigned or unbound target.
- A stale PID or mismatched executable/start time is rejected.
- Unsupported or denied operations never return success.
- No automatic administrator/root escalation occurs.
- Restoration never overwrites a later user/OS priority change.
- Documentation and UI distinguish implemented, unsupported, and unverified behavior.
- Windows, Linux, and macOS are assessed independently; untested platform behavior remains unverified.

## Current decision

**Do not enable process-priority writes yet.** The authenticated target-identity protocol is a prerequisite. Implementing priority writes before that prerequisite would add a process-control capability without sufficient target binding and rollback guarantees.
