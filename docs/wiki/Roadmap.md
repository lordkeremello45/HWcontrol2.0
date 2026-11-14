# Roadmap

This is a forward-looking engineering plan, not a feature-completion checklist. For implemented behavior and current limitations, see [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md).

The following items are documentation/planning targets rather than promises of a release date.

## Release hardening

- cross-platform package validation is implemented in GitHub Actions;
- Windows MSI and guided Setup.exe installation/uninstallation are smoke-tested;
- Linux DEB installation is validated on Ubuntu;
- macOS native release validation runs on Apple Silicon;
- release integrity generates and verifies SHA-256, SHA-512 and SHA3-512 manifests;
- a manual release-readiness gate checks package assets and publisher-signing configuration.

## Feature expansion

- **Implemented:** point-based fan-curve editor with local persistence and capability-gated automatic evaluation;
- **Implemented:** bounded CPU microbenchmark;
- **Implemented:** local temperature automation rules;
- **Implemented:** extension metadata/capability contract;
- richer multi-series hardware graphs beyond the current CPU/GPU temperature and CPU utilization views;
- broader hardware-control backends, beginning with validated Windows vendor/OEM adapters and expanded Linux device coverage;
- additional package-native formats where maintenance is justified.

## Trust / distribution

- production Windows publisher signing when certificate secrets are provisioned;
- production Apple Developer ID signing and notarization when Apple credentials are provisioned;
- potential SignPath integration;
- stronger release provenance and verification UX.

The C++ Game Core, BSOD Shield, full SPARK runtime integration, universal cross-platform power-mode automation beyond the existing Windows 11/Linux adapters, liquid-cooling control, and additional platform hardware adapters must not be described as shipped capabilities until their implementation and validation gates are met.

The actual release status should always be determined from the repository, current GitHub Actions runs and GitHub Releases.
