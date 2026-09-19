# Code Signing

## Windows

The Windows setup workflow can use:

- `WINDOWS_CERTIFICATE_B64`
- `WINDOWS_CERTIFICATE_PASSWORD`

to construct a temporary PFX, sign Setup.exe with SignTool using SHA-256 and a timestamp server, and verify the result with `signtool verify /pa /all`.

When those secrets are absent, the release remains unsigned.

## macOS

Production Developer ID Application / Installer signing and notarization require Apple-issued credentials.

## Important distinction

- SHA-256 = artifact integrity
- GitHub attestation = build/provenance signal
- Authenticode / Developer ID = publisher identity and OS trust

One does not replace another.
