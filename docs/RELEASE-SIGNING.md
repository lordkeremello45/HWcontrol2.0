# HWControl Release Signing & Trust

This document defines the production trust layers added on top of the existing build, installer, release, and SHA-256 architecture.

## Trust model

1. GitHub Actions builds and validates the artifacts.
2. Windows artifacts are Authenticode-signed when signing secrets are configured.
3. macOS applications/packages are Developer ID signed and notarized when Apple credentials are configured.
4. Every release keeps its existing individual `.sha256` files.
5. `release-integrity.yml` verifies those checksums and publishes a release-wide `SHA256SUMS.txt` without replacing existing assets.
6. Release provenance/attestation can be enabled independently as an additional supply-chain control.

## Windows production signing

Use a code-signing certificate issued by a publicly trusted CA. Store the certificate/private key in GitHub Actions secrets or a protected production environment; never commit it to the repository.

Recommended secrets:

- `WINDOWS_SIGNING_CERT_BASE64` — base64-encoded PFX certificate
- `WINDOWS_SIGNING_CERT_PASSWORD` — PFX password

Sign the application binaries before packaging the MSI, then sign the final MSI as well. Verify with `signtool verify /pa`.

Signing does not guarantee that Microsoft SmartScreen will immediately show no warning; SmartScreen reputation is a separate trust signal that grows with legitimate distribution history.

## macOS production signing

Use Apple Developer Program credentials and Developer ID certificates.

Required certificate roles:

- Developer ID Application — signs `HWControl.app` and executable components.
- Developer ID Installer — signs the final `.pkg`.

Notarization requires App Store Connect API credentials or another supported `notarytool` authentication method. Keep the private key and certificate material in protected GitHub secrets/environment variables.

Production flow:

`codesign` → build PKG/DMG → `productsign` PKG → `notarytool submit --wait` → `stapler staple` → `spctl` / `codesign` / `pkgutil` verification.

Do not use `|| true` for the final production signature/notarization gate.

## SHA-256

SHA-256 is an integrity mechanism, not proof of publisher identity. A valid release should therefore have both:

- a cryptographic publisher signature; and
- a SHA-256 digest for reproducible integrity verification.

The existing platform-specific release model remains supported. A future unified release tag can use the same integrity workflow without requiring this architecture to be rewritten.

## Release security rules

- Never commit private keys, PFX/P12 files, Apple API private keys, passwords, or certificates containing private material.
- Prefer a protected GitHub `production` environment for signing jobs.
- Require approval before a production signing job can access signing secrets.
- Keep release assets immutable after publication except for controlled metadata/manifests.
- Verify checksums before installation and fail closed on mismatch.
