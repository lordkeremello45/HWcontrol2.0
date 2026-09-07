# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Release integrity

Release packages are published only from the official GitHub repository. Each
platform package has a matching `.sha256` file. Verify a download before
running it.

Linux:

```sh
sha256sum -c HWControl-vX.Y.Z-linux-Linux-x64.sha256
```

Windows:

```powershell
Get-FileHash .\HWControl-vX.Y.Z-windows-Windows-x64.zip -Algorithm SHA256
```

For a local Windows package, the repository also includes an offline verifier:

```powershell
.\installer\verify-windows-release.ps1 `
  -Artifact .\HWControl-vX.Y.Z-windows-Windows-x64.msi `
  -ChecksumFile .\HWControl-vX.Y.Z-windows-Windows-x64.sha256
```

### Why Windows may still show SmartScreen

HWControl releases may be distributed unsigned while the project is open source.
SHA-256 verification and GitHub Actions provenance establish **artifact
integrity and build provenance**, but they do not create a Windows publisher
identity. Therefore an unsigned Windows EXE/MSI can still display **Unknown
publisher** or **Windows protected your PC** / SmartScreen warnings.

These warnings cannot be legitimately removed by changing the installer,
renaming files, or attempting to bypass SmartScreen. The supported way to
establish publisher identity is Authenticode code signing with a certificate.

Until code signing is enabled, users should obtain packages only from the
official repository release and verify the published SHA-256 checksum before
execution. The release workflow is prepared to enable Authenticode signing
later through protected GitHub Actions secrets without changing the package
layout.

The dashboard does not install or execute updates automatically. It accepts
only HTTPS links to the allowlisted GitHub repository and requires a release
checksum asset before showing an update.

## Reporting a vulnerability

Please report security issues privately through the repository's GitHub
Security tab. Do not publish credentials, private keys, or exploit details in
a public issue. We will acknowledge reports and provide a remediation status
when the investigation is complete.
