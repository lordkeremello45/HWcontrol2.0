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
- [ ] Verify fresh workflow runs start and execute their intended Go checks.

### Task 2: Restore npm vulnerability scanning

**Files:** Modify `.github/workflows/osv-vulnerability-scan.yml`.

- [x] Confirm failure from the job log: setup-node rejects `cache: false`.
- [x] Replace it with `package-manager-cache: false`; keep the package install and OSV scan.
- [ ] Verify fresh workflow run reaches and completes the website dependency scan.

### Task 3: Record references and review

**Files:** Modify `docs/REFERENCES.md`; add this design and plan.

- [x] Add official setup-go/setup-node, Go fuzzing and OSV-Scanner sources.
- [ ] Inspect the resulting commit and fresh CI evidence; list any pending/failed follow-up.


### Task 4: Normalize existing Go formatting

**Files:** All tracked `bridge_service/**/*.go` files reported by the existing formatter gate.

- [x] Reproduce the format-only failure through the security-services job log; retain the existing check.
- [x] Use the standard Go formatter, not hand-written whitespace edits.
- [x] Standard `gofmt` repair committed as `ddbc04405b3a11105d6c153f400e5c40c3f68323`; normal security-services verification still pending.
- [ ] Verify `go vet ./...` and `go test -race -count=1 ./...` on the formatted tree.
- [ ] Remove the one-time formatting workflow and verify the normal CI workflow on the resulting `main` commit.


### Task 5: Correct the audio-protocol fuzz assertion

**Files:** Modify `bridge_service/src/security_fuzz_test.go`.

- [x] Reproduce the failure in the scheduled fuzz run: a valid seed fails the check that claims to detect line breaks.
- [x] Root cause: `strings.ContainsAny(line, "\\r\\n")` examines literal backslash, `r`, and `n`, so it rejects ordinary protocol text containing those letters (including the `start` command) instead of checking carriage-return/newline bytes.
- [x] Correct the assertion to `strings.ContainsAny(line, "\r\n")`, preserving the intended CR/LF injection safety property.
- [ ] Re-run `FuzzAudioStudioJSONPayload` and the full fuzz job; report the real result.
