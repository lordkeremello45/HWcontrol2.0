# CI Security Gate Recovery — Design

**Date:** 2026-10-24  
**Status:** Implemented; awaiting GitHub Actions verification.

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
