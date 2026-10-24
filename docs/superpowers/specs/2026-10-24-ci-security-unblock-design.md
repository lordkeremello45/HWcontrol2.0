# CI Security Gate Recovery — Design

**Date:** 2026-10-24  
**Status:** CI gate fixes verified for Go formatting/security services and fuzzing; UTF-8 stream regression test and updated replay smoke assertions are awaiting their current GitHub Actions runs.

## Intent

Restore existing automated security controls that are failing before their checks execute. HWcontrol2.0 treats security and release validation as operational controls, not decorative workflow files.

## Observed evidence

- Security boundary fuzzing run: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/39932964245 — setup failed because the referenced `actions/setup-go` revision could not be resolved.
- OSV dependency scan run: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/39932085878 — Pub and NuGet scans passed; website npm dependency scanning stopped at `actions/setup-node` with `Caching for 'false' is not supported`.
- The same invalid Go action revision appears in `.github/workflows/security-services.yml`.

## Additional finding

After the Go action pin was repaired, the security-services workflow began and exposed a pre-existing formatting failure: `gofmt -l src security_guardian` reported more than 30 Go source/test files. This is a quality-gate failure, not evidence of a security vulnerability. The formatter must be applied mechanically; the gate must remain enabled.

## Goals

- Correct the action reference using the known-good pinned revision already used by other workflows in this repository.
- Disable setup-node's automatic package-manager cache using its supported input, preserving the npm dependency scan.
- Preserve least-privilege workflow permissions and all test/scanner steps.
- Add the official action, Go fuzzing and OSV-Scanner documentation to the technical references registry.

## Non-goals

- Do not mute or skip fuzzing or vulnerability scanning.
- Do not claim that the repository has no vulnerable dependencies.
- Do not change application behavior, upgrade dependency versions, or add third-party implementation code in this repair.

## Approaches considered

1. **Repair exact workflow inputs and pins (chosen):** minimal diff, keeps current security gates and SHA pinning.
2. Replace SHA-pinned actions with major-version tags: rejected because it weakens supply-chain reproducibility.
3. Disable affected jobs or use `continue-on-error`: rejected because it hides loss of security coverage.

## Constraints and acceptance

The repository's existing architecture and direct-`main` workflow are retained. Acceptance requires the affected GitHub Actions jobs to start and complete; a successful workflow configuration alone is not evidence that fuzzing or vulnerability scanning passed. Hardware behavior and all product surfaces remain outside the scope of this narrow recovery batch.


## Additional data-path finding

The Flutter dashboard created the bridge response stream with `socket.map(utf8.decode)`. That decodes each transport chunk separately; a multibyte UTF-8 codepoint split between chunks can raise a decoding error before the line is parsed. The dashboard now uses a streaming UTF-8 decoder followed by `LineSplitter`, with a regression test that splits the bytes for a Turkish character across chunks. Official Dart API references are recorded in `docs/REFERENCES.md`.

## Additional smoke-test finding

The Windows loopback smoke test showed the backend correctly rejecting a reused nonce with message `nonce rejected by replay protection`; the script incorrectly matched only `replayed`. Linux and Windows smoke checks now assert the error status plus a case-appropriate `replay` token. The security behavior remains enabled and tested.

## Verified evidence to date

- Go security services: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657084 — all steps passed, including formatting, race-enabled bridge tests, static analysis, Windows amd64 cross-build and security guardian smoke tests.
- IPC boundary fuzzing: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079657142 — all four fuzz targets passed after correcting the false-positive CR/LF assertion.
- OSV scan: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079678138 — full-repository and npm scan jobs passed at last observation; remaining language-specific jobs were still running.
- IPC smoke suite: https://github.com/lordkeremello45/HWcontrol2.0/actions/runs/40079893921 — Linux passed; macOS and Windows were in progress at last observation.
