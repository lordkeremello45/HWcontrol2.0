# HWControl Release Verification

HWControl releases use multiple independent verification layers. Use more than one layer when possible.

## 1. SHA-256

SHA-256 detects accidental corruption or a modified download when the expected digest comes from a trusted release channel.

Linux/macOS:

```bash
sha256sum -c HWControl-<tag>-<platform>-x64.sha256
```

On macOS, `shasum -a 256 -c <manifest>` can be used when `sha256sum` is unavailable.

Windows PowerShell:

```powershell
(Get-FileHash .\HWControl-<package>.zip -Algorithm SHA256).Hash
```

Compare the result with `SHA256SUMS.txt` from the same GitHub release.

## 2. SHA-512

Each verified release also receives a release-wide `SHA512SUMS.txt` manifest. SHA-512 is an independent digest algorithm and provides an additional integrity check.

Linux:

```bash
sha512sum -c SHA512SUMS.txt
```

macOS:

```bash
shasum -a 512 -c SHA512SUMS.txt
```

Windows PowerShell:

```powershell
(Get-FileHash .\HWControl-<package>.zip -Algorithm SHA512).Hash
```

## 3. GitHub artifact attestations

Build workflows publish GitHub artifact attestations for release packages. Where an attestation is available, verify the artifact with the GitHub CLI:

```bash
gh attestation verify HWControl-<package> -R lordkeremello45/HWcontrol2.0
```

An attestation provides provenance information tied to the GitHub Actions workflow. It is not the same thing as a Windows Authenticode or Apple Developer ID signature.

## 4. Publisher signatures

OS-trusted publisher signatures remain a separate layer:

- Windows: Authenticode certificate and, for production kernel drivers, the applicable Microsoft signing/attestation process.
- macOS: Developer ID Application/Installer plus Apple notarization.

Unsigned Windows artifacts must never be presented as publisher-signed merely because their SHA-256 or SHA-512 digest matches.

## Trust model

```text
Downloaded artifact
       |
       +--> SHA-256 match ---------> integrity
       |
       +--> SHA-512 match ---------> independent integrity
       |
       +--> GitHub attestation ----> build provenance
       |
       +--> OS publisher signature -> publisher/OS trust
```

A checksum does not authenticate the publisher by itself. For the strongest verification, obtain the release from the official GitHub repository and verify both the digest and the available provenance/signature evidence.

## Private key policy

Private signing keys must never be committed to this repository. If a future static Ed25519/Minisign release key is introduced, only its public verification key and fingerprint belong in the repository; the private key must remain in a protected signing environment or GitHub secret.
