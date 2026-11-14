# Release Pipeline

The release gate is an evidence-first pipeline. Package creation is not equivalent to a releasable artifact.

## Required flow

```text
Immutable source SHA / tag
    ↓
C++ / CMake + Go + Flutter build, unit and static checks
    ↓
Parallel native platform package jobs
    ↓
Install + launch + bridge IPC + uninstall/cleanup smoke tests
    ↓
All platform gates pass?
    ├─ No → collect full logs → classify root cause → fix + regression test → rerun failed gate
    └─ Yes
         ↓
SHA-256 manifests + artifact attestations
    ↓
Exact asset matrix + tag/SHA verification
    ↓
GitHub Release publication
    ↓
Read back assets + verify checksums / attestations
    ↓
Release accepted
```

Any failed platform smoke test, missing required asset, checksum/attestation failure or tag/SHA mismatch blocks publication. Do not remove tests or use `continue-on-error` to make the gate green.

## Beta artifact contract

| Platform | Required files |
|---|---|
| Windows x64 | guided Setup.exe, MSI, portable ZIP, portable 7Z |
| Windows MSIX | unsigned preview artifact only; not production-trusted |
| Linux x64 | DEB, TAR.GZ, TAR.ZST, ZIP |
| macOS arm64 | PKG, DMG, app-bundle ZIP containing `HWControl.app` |

A macOS `.app` is a directory bundle. `.apt` is not a package extension: APT distribution is a signed repository containing DEB packages and metadata. A generic `.tar.zst` is not an Arch package; native Arch packaging requires `.pkg.tar.zst`.

## Historical recovery notes

The Windows WiX/DPAPI/shortcut, Linux systemd socket-readiness, and macOS LaunchDaemon packaging issues recorded during the 2026-11-05 recovery work are historical context, not a current CI status report. Their fixes must be evaluated from the latest workflow runs for the exact commit. Do not carry forward a queued/pending status snapshot as current evidence.

## Current release workflows

- `beta-release.yml` is the unified manual Beta workflow. It validates the source version and immutable tag, builds Windows/Linux/macOS package sets, and publishes one cross-platform prerelease when `publish=true`.
- `automatic-patch-release.yml` dispatches a unified Beta release after a successful main-branch cross-platform package-validation run.
- `build-selected-release.yml` remains a manual platform-selection dispatcher for platform-specific package workflows.
- `final-release.yml` is the manual coordinated stable-release gate and requires physical hardware evidence plus platform signing configuration.

Always inspect the latest workflow results and release assets before describing a particular tag as validated.

## Integrity terminology

- SHA-256 verifies artifact bytes against a manifest.
- Artifact attestation binds build provenance to an artifact.
- Authenticode, Developer ID signing/notarization, and GPG/Ed25519 signatures establish different trust properties.
- Never claim a package is signed merely because it has checksums or an attestation.
