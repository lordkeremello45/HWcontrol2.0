# HWcontrol2.0 Stable Final Release Runbook

This runbook describes the coordinated stable release process. It does not claim that a release has passed until the GitHub Actions run and all platform readiness jobs have succeeded.

## Release source

The current source version is read from gui_dashboard/pubspec.yaml. The workflow requires the requested version to match that value and resolves one immutable source commit before creating platform tags.

For version 0.3.1, the platform tags are:

- v0.3.1-windows
- v0.3.1-linux
- v0.3.1-macos

The three builds must use the same source commit.

## Required repository Actions secrets

Configure these under Repository → Settings → Secrets and variables → Actions. Never paste private keys, passwords or certificates into chat, issues, logs or source files.

### Windows Authenticode

- WINDOWS_CERTIFICATE_B64 — base64-encoded PFX containing a publicly trusted code-signing certificate.
- WINDOWS_CERTIFICATE_PASSWORD — PFX password.

The release workflow signs PE payloads before packaging, then signs the MSI and Setup EXE. Final readiness verifies the published signatures and trust chain.

### macOS Developer ID and notarization

- APPLE_CERTIFICATE_P12_B64 — base64-encoded Developer ID certificate bundle.
- APPLE_CERTIFICATE_PASSWORD — P12 password.
- APPLE_SIGNING_IDENTITY — Developer ID Application identity.
- APPLE_INSTALLER_IDENTITY — Developer ID Installer identity.
- APPLE_API_KEY_B64 — base64-encoded App Store Connect API private key.
- APPLE_API_KEY_ID — API key ID.
- APPLE_API_ISSUER — API issuer UUID.

The release workflow signs the app and native helpers, signs the PKG, submits the PKG and DMG for notarization, staples the tickets, and verifies them.

### Linux release-manifest signing

- HWCONTROL_GPG_PRIVATE_KEY_B64 — base64-encoded HWControl Release private key.
- HWCONTROL_GPG_PASSPHRASE — private-key passphrase.

The imported primary-key fingerprint must match HWControl-GPG-fingerprint.txt. The workflow signs and verifies the Linux platform SHA-256 manifest before publication.

### APT repository signing

- APT_GPG_PRIVATE_KEY — dedicated APT archive-signing private key.

Its primary fingerprint must be exactly 17B2AAC6F057A3AD4C43EF4BD150613F605FA463. This key is separate from the Linux release-manifest GPG key. Both the repository builder and client setup script enforce the fingerprint.

## Run the final release

1. Confirm the main branch contains the intended source and that gui_dashboard/pubspec.yaml has the intended stable version.
2. Confirm all required secrets above are configured and valid.
3. Confirm docs/HARDWARE-VALIDATION-MATRIX.md contains complete VERIFIED physical-device evidence for Windows, Linux and macOS. CI and virtual machines do not satisfy this gate.
4. After all acceptance criteria are genuinely met, update README, USER-QUICKSTART, honestdescription and PRODUCT-READINESS-CHECKLIST to describe the stable channel and preserve all known limitations. Do not change their Beta status before the evidence exists.
5. Open GitHub → Actions → Final release — all platforms.
6. Run the workflow with the version (for example, 0.3.1) and source ref main or an exact 40-character commit SHA.
7. The workflow checks credentials and source version before creating tags. It then dispatches Windows, Linux and macOS release builds, generates and attests an SPDX SBOM for each platform, runs strict release readiness, and synchronizes website release metadata and the signed APT repository.
8. Treat the release as final only if the top-level workflow and all platform readiness jobs finish successfully.

## Acceptance gates

- Stable platform tags point to the same immutable source commit.
- Required platform installers and archives exist and are non-empty.
- Every entry in each SHA-256 manifest verifies against its downloaded asset.
- GitHub artifact attestations verify for packages and SBOMs.
- Windows Authenticode signatures validate on a Windows runner.
- macOS Developer ID signatures, package signature and notarization tickets validate on macOS.
- Linux GPG signature validates against the pinned release-key fingerprint.
- Website release metadata and Pages/APT deployment complete successfully.

## Post-release physical validation

GitHub-hosted runners cannot certify hardware-specific behavior. Before advertising broad hardware support, record real-device tests for:

- Windows 10/11 x64 on representative CPU/GPU/motherboard combinations;
- Debian/Ubuntu-family Linux x64 with the required permissions and sensor interfaces;
- macOS 14+ Apple Silicon;
- sensor accuracy, missing-sensor handling, fan RPM, supported fan control, thermal emergency behavior, service startup/shutdown, upgrade and uninstall.

A successful software release gate is not proof of universal hardware compatibility. Keep unsupported control paths monitor-only and publish the tested hardware matrix with each release.
