# HWControl Release Signing & Trust

This document defines the trust layers used by HWControl 2.0 and clearly separates the **free integrity pipeline** from optional paid platform signing.

## Free release mode

HWControl can be built and published without buying a code-signing certificate. In this mode the project uses:

1. GitHub Actions build validation.
2. GitHub artifact provenance/attestation where enabled by the workflow.
3. SHA-256 checksums for published packages.
4. Installer/package smoke tests before publication.
5. Explicit signing-state reporting so an unsigned artifact is never presented as signed.

These controls improve supply-chain integrity and let users verify that a downloaded artifact matches the published artifact. They **do not create an OS-trusted publisher signature**.

A self-signed certificate is intentionally not generated as a substitute. It would not establish public Windows/macOS publisher trust and could mislead users about the security state of the release.

## Windows

When `WINDOWS_CERTIFICATE_B64` and `WINDOWS_CERTIFICATE_PASSWORD` GitHub Actions secrets are configured, the existing workflow can sign PE files and the final MSI/Setup.exe with SignTool.

When those secrets are absent, Windows artifacts remain unsigned and the release metadata must say so.

The following are separate production trust mechanisms and cannot be replaced by a free GitHub Actions setting:

- A publicly trusted Authenticode certificate for Windows publisher signing.
- Microsoft Hardware Dev Center signing/attestation for production kernel-mode drivers.

## macOS

The free pipeline can build Apple Silicon packages, validate installation, generate SHA-256 checksums, and produce GitHub provenance.

Developer ID signing and Apple notarization require Apple-issued signing credentials, so the free pipeline must not claim that a package is notarized or Developer ID signed when those credentials are unavailable.

## Verification

Users should verify the published SHA-256 manifest before installing an artifact. GitHub provenance/attestation can provide an additional supply-chain signal when available.

**Important:** checksums and attestations verify artifact integrity/provenance; they do not replace OS-trusted code signing.

## Production signing (when credentials are available)

### Windows

Use a publicly trusted code-signing certificate. Keep certificate/private-key material outside the repository, preferably in a protected GitHub environment.

Recommended secrets:

- `WINDOWS_CERTIFICATE_B64` — base64-encoded PFX certificate
- `WINDOWS_CERTIFICATE_PASSWORD` — PFX password

Sign application binaries before packaging and sign the final installer as well. Verify with `signtool verify /pa`.

### macOS

Use Apple Developer Program credentials and Developer ID certificates:

- Developer ID Application — signs `HWControl.app` and executable components.
- Developer ID Installer — signs the final `.pkg`.

Production flow:

`codesign` → build PKG/DMG → `productsign` PKG → `notarytool submit --wait` → `stapler staple` → `spctl` / `codesign` / `pkgutil` verification.

Do not use `|| true` for a final production signature or notarization gate.

## SHA-256

SHA-256 is an integrity mechanism, not proof of publisher identity. A production release should therefore have both a trusted publisher signature and a SHA-256 digest.

## Security rules

- Never commit private keys, PFX/P12 files, Apple API private keys, passwords, or private signing material.
- Prefer a protected GitHub production environment for signing jobs.
- Require approval before a production signing job can access signing secrets.
- Verify checksums before installation and fail closed on mismatch.
