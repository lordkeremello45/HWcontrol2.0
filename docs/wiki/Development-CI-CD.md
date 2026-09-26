# CI/CD

The repository uses GitHub Actions for cross-platform build validation, packaging and release integrity.

Important workflows include:

- `.github/workflows/platform-validation.yml`
- `.github/workflows/windows-setup-release.yml`
- Platform-specific release workflows (Windows/Linux/macOS) generate and validate package checksums.
- GitHub artifact attestations are generated where the release workflow enables them.

CI should be treated as part of the build/security surface because packaging, checksums, attestations and release publication are repository-controlled. Release-wide GPG/Ed25519 manifest signing is documented as a verification path but is not currently an active push-triggered workflow.
