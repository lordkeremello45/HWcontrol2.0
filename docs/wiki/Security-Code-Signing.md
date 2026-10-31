# Code Signing

## Windows

The Windows release workflow uses:

- `WINDOWS_CERTIFICATE_B64` — base64-encoded PFX certificate
- `WINDOWS_CERTIFICATE_PASSWORD` — PFX password

The release pipeline signs the PE payload before packaging, then signs the MSI and final Setup EXE. Every signed file is checked with `signtool verify /pa /all`. If either secret is absent, artifacts remain unsigned. The final-release gate inspects the published MSI, Setup EXE and executable payload signatures; secret presence alone is not accepted as proof.

## macOS

The macOS release workflow requires all of these secrets to sign and notarize:

- `APPLE_CERTIFICATE_P12_B64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY` (Developer ID Application)
- `APPLE_INSTALLER_IDENTITY` (Developer ID Installer)
- `APPLE_API_KEY_B64`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER`

The workflow signs native helpers and the app, signs the PKG, submits the PKG and DMG to Apple notarization, staples both tickets, and verifies the results. Partial credentials fail closed. If no Apple credentials are configured, the package remains unsigned and final-release readiness fails.

## Linux

The Linux release manifest uses the dedicated HWControl Release OpenPGP key:

- `HWCONTROL_GPG_PRIVATE_KEY_B64`
- `HWCONTROL_GPG_PASSPHRASE`

The release workflow verifies the primary fingerprint from `HWControl-GPG-fingerprint.txt`, signs the platform SHA-256 manifest, and verifies the detached signature before publishing. The APT repository uses a separate key, `APT_GPG_PRIVATE_KEY`, pinned to `17B2AAC6F057A3AD4C43EF4BD150613F605FA463`.

## Coordinated final release

Run **Final release — all platforms** from GitHub Actions. It checks the source version and required signing secrets before creating tags, builds Windows/Linux/macOS packages from one immutable commit, then runs the strict per-platform readiness gate. It synchronizes website release metadata and the signed APT repository only after all three platform gates pass.

The per-platform **Final release readiness** workflow verifies required package assets, every SHA-256 manifest entry, GitHub artifact attestations, Windows Authenticode, macOS Developer ID/notarization, and the Linux GPG manifest signature.

## Important distinction

- SHA-256 = artifact integrity
- GitHub attestation = build provenance
- GPG = Linux release-manifest signer authenticity (with pinned fingerprint)
- Authenticode / Developer ID = publisher identity and OS trust

One does not replace another.
