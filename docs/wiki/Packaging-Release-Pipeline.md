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

## Current recovery state — 2026-11-05

Root causes found in the prior failed beta jobs:
- Windows: WiX relative `PackageDir` caused zero harvested files; LocalService could not unprotect the user-scoped DPAPI key; shortcut assertions looked in per-user paths while MSI installed machine-wide shortcuts.
- Linux: the smoke test checked the bridge socket immediately after systemd reported a `Type=simple` service active.
- macOS: `postinstall` used `/usr/bin/test`; the guardian LaunchDaemon plist was not copied to the app root; upgrade cleanup handled only the bridge daemon.

Focused fixes and artifact-matrix updates are committed to `main`. **CI is pending; these changes are not yet VERIFIED.** See [current workflow runs](https://github.com/lordkeremello45/HWcontrol2.0/actions).

## Integrity terminology

- SHA-256 verifies artifact bytes against a manifest.
- Artifact attestation binds build provenance to an artifact.
- Authenticode, Developer ID signing/notarization, and GPG/Ed25519 signatures establish different trust properties.
- Never claim a package is signed merely because it has checksums or an attestation.
