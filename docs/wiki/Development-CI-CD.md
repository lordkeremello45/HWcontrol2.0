# CI/CD

The repository uses GitHub Actions for cross-platform build validation, packaging and release integrity.

Important workflows include:

- `.github/workflows/platform-validation.yml`
- `.github/workflows/windows-setup-release.yml`
- `.github/workflows/release-integrity.yml`

CI should be treated as part of the build/security surface because packaging, checksums, signing and release publication are all driven by repository-controlled workflows.
