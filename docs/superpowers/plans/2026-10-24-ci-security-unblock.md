# CI Security Gate Recovery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore execution of the existing IPC fuzzing, security-services, and npm dependency-scan gates without weakening them.

**Architecture:** Keep existing GitHub Actions workflows and scanners. Replace one invalid pinned action revision in two workflows and replace one unsupported setup-node input with the supported opt-out for automatic package-manager caching.

**Tech Stack:** GitHub Actions YAML, Go test fuzzing, Node.js setup action, OSV-Scanner.

**Spec:** `docs/superpowers/specs/2026-10-24-ci-security-unblock-design.md`

## Global Constraints

- Keep actions pinned to verified commit SHAs.
- Do not remove, skip, or soften existing security checks.
- Preserve `persist-credentials: false` and least-privilege permissions.
- Keep `docs/REFERENCES.md` as the canonical technical reference registry.

## Review Focus

1. Invalid action SHA prevents scheduled fuzzing from starting — inspect the action-resolution step and wait for fuzz jobs.
2. Unsupported cache input aborts the website scan before dependency resolution — inspect the Node setup and npm scan steps.
3. Reference updates must document the official sources actually used — inspect the changed technical-reference sections.
4. Other valid `cache: false` inputs must remain untouched — scope the change to `actions/setup-node`.
5. No success claim should precede a fresh CI run — inspect the new run IDs, statuses, conclusions and job logs.

---

### Task 1: Restore Go security jobs

**Files:** Modify `.github/workflows/security-fuzz.yml` and `.github/workflows/security-services.yml`.

- [x] Confirm failure from the workflow logs: the invalid action revision could not be resolved.
- [x] Replace only the invalid setup-go SHA with the already-used valid pinned SHA.
- [x] Verified on https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657084 (all Security services steps passed) and https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657142 (all four fuzz targets passed).

### Task 2: Restore npm vulnerability scanning

**Files:** Modify `.github/workflows/osv-vulnerability-scan.yml`.

- [x] Confirm failure from the job log: setup-node rejects `cache: false`.
- [x] Replace it with `package-manager-cache: false`; keep the package install and OSV scan.
- [x] Website npm and full repository scans passed in https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079678138; the remaining language-specific subjobs were still running at last check.

### Task 3: Record references and review

**Files:** Modify `docs/REFERENCES.md`; add this design and plan.

- [x] Add official setup-go/setup-node, Go fuzzing and OSV-Scanner sources.
- [x] References and plan/spec were reviewed against the live workflow logs. Remaining full cross-platform checks are tracked separately below.


### Task 4: Normalize existing Go formatting

**Files:** All tracked `bridge_service/**/*.go` files reported by the existing formatter gate.

- [x] Reproduce the format-only failure through the security-services job log; retain the existing check.
- [x] Use the standard Go formatter, not hand-written whitespace edits.
- [x] Standard `gofmt` repair committed as `ddbc04405b3a11105d6c153f400e5c40c3f68323`; normal security-services verification still pending.
- [x] `gofmt`, Go static analysis, race-enabled bridge tests, Windows amd64 cross-build, security guardian build and guardian smoke test passed in https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657084. Note: the one-time broader `go test -race ./...` attempt first exposed the fuzz-assertion defect below, which was then fixed.
- [x] Removed `.github/workflows/temporary-gofmt-repair.yml` in commit `fcd42a6540f5fbb078d7a947223b6a9e9678201f`; the normal CI runs on the current `main` are linked in the final report.


### Task 5: Correct the audio-protocol fuzz assertion

**Files:** Modify `bridge_service/src/security_fuzz_test.go`.

- [x] Reproduce the failure in the scheduled fuzz run: a valid seed fails the check that claims to detect line breaks.
- [x] Root cause: `strings.ContainsAny(line, "\\r\\n")` examines literal backslash, `r`, and `n`, so it rejects ordinary protocol text containing those letters (including the `start` command) instead of checking carriage-return/newline bytes.
- [x] Correct the assertion to `strings.ContainsAny(line, "\r\n")`, preserving the intended CR/LF injection safety property.
- [x] All four fuzz targets passed in https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657142.


### Task 6: Make the bridge-to-GUI UTF-8 stream robust

**Files:** Modify `gui_dashboard/lib/main.dart`; add `gui_dashboard/lib/services/bridge_line_decoder.dart` and a unit test.

- [x] Root cause found in the stream setup: `socket.map(utf8.decode)` independently decoded chunks, which can split a multibyte UTF-8 character.
- [x] Change to one streaming decoder before line splitting and add a regression test that splits the UTF-8 sequence for a Turkish character across two chunks.
- [ ] Verify Flutter analyze and unit tests on the resulting commit.

### Task 7: Align replay-smoke assertions with the bridge contract

**Files:** Modify `.github/workflows/local-ipc-smoke.yml`.

- [x] Logs confirmed the bridge correctly rejects a reused nonce with `nonce rejected by replay protection`; the smoke assertion incorrectly required the word `replayed`.
- [x] Linux and Windows assertions now require an error and the semantic token `replay`, without changing or bypassing replay rejection.
- [ ] Verify Linux, macOS and Windows smoke jobs on https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079893921.


### Task 8: Fix the installer model-manager import

**Files:** Modify `gui_dashboard/lib/installer_main.dart`.

- [x] Flutter analyze and the MSIX dashboard test run identified `import 'model_manager.dart'`, but the existing class is under `services/ai/model_manager.dart`.
- [x] Correct the URI to the existing source module; keep the installer's model-ready/download behavior intact.
- [ ] Verify Flutter analysis and dashboard tests on the resulting commit.

### Task 9: Fix the native audio probe compile error

**Files:** Modify `audio_core/tools/audio_device_probe.cpp`.

- [x] Linux CMake build showed two unqualified `DeviceDirection` references inside `handleServerCommand`, outside the function scope where a local using-declaration exists.
- [x] Use the enum's declared `hwcontrol::audio` namespace in both references; keep audio behavior unchanged.
- [ ] Verify native Linux/macOS and Windows C++ builds on the resulting commit.
