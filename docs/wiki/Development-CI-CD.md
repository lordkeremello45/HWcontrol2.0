# CI/CD

The repository uses GitHub Actions for cross-platform build validation, packaging and release integrity.

Important workflows include:

- `.github/workflows/platform-validation.yml`
- `.github/workflows/final-release.yml` coordinates immutable Windows/Linux/macOS stable tags, signing-secret preflight, package builds, strict readiness gates, and website/APT synchronization.
- `.github/workflows/release-readiness.yml` verifies required assets, SHA-256 manifests, GitHub attestations, Windows Authenticode, macOS Developer ID/notarization, and Linux GPG signatures.
- `.github/workflows/sbom.yml` generates SPDX SBOMs and attaches an attestation to each stable platform release.
- `docs/HARDWARE-VALIDATION-MATRIX.md` is the mandatory physical-device evidence gate; CI and VMs do not count as hardware validation.
- `docs/FINAL-RELEASE-RUNBOOK.md` lists the required signing secrets and operator procedure.
- `.github/workflows/release.yml` (Windows release packaging and MSI/ZIP validation)
- Platform-specific release workflows (Windows/Linux/macOS) generate and validate package checksums.
- GitHub artifact attestations are generated where the release workflow enables them.

CI should be treated as part of the build/security surface because packaging, checksums, attestations and release publication are repository-controlled. Release-wide GPG/Ed25519 manifest signing is documented as a verification path but is not currently an active push-triggered workflow.
