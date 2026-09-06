# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Release integrity

Release packages are published only from the official GitHub repository. Each
platform package has a matching `.sha256` file. Verify a download before
running it:

```sh
sha256sum -c HWControl-vX.Y.Z-linux-Linux-x64.sha256
```

Windows users can calculate the same value with:

```powershell
Get-FileHash .\HWControl-vX.Y.Z-windows-Windows-x64.zip -Algorithm SHA256
```

The dashboard does not install or execute updates automatically. It accepts
only HTTPS links to the allowlisted GitHub repository and requires a release
checksum asset before showing an update.

## Reporting a vulnerability

Please report security issues privately through the repository's GitHub
Security tab. Do not publish credentials, private keys, or exploit details in
a public issue. We will acknowledge reports and provide a remediation status
when the investigation is complete.
