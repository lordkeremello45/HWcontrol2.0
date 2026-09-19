# Roadmap

The following items are documentation/planning targets rather than promises of a release date.

## Release hardening

- cross-platform package validation is implemented in GitHub Actions;
- Windows MSI and guided Setup.exe installation/uninstallation are smoke-tested;
- Linux DEB installation is validated on Ubuntu;
- macOS native release validation runs on Apple Silicon;
- release integrity generates and verifies SHA-256, SHA-512 and SHA3-512 manifests;
- a manual release-readiness gate checks package assets and publisher-signing configuration.

## Feature expansion

- true point-based fan-curve editor;
- richer multi-series hardware graphs;
- process-aware Game Mode;
- broader hardware-control backends;
- additional package-native formats where maintenance is justified.

## Trust / distribution

- production Windows publisher signing when certificate secrets are provisioned;
- production Apple Developer ID signing and notarization when Apple credentials are provisioned;
- potential SignPath integration;
- stronger release provenance and verification UX.

The actual release status should always be determined from the repository and GitHub Releases.
