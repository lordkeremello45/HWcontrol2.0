# Code Signing

## Windows

The Windows setup workflow can use:

- `WINDOWS_CERTIFICATE_B64`
- `WINDOWS_CERTIFICATE_PASSWORD`

to construct a temporary PFX, sign Setup.exe with SignTool using SHA-256 and a timestamp server, and verify the result with `signtool verify /pa /all`.

When those secrets are absent, the release remains unsigned.

## macOS

Production Apple trust requires Apple-issued credentials. The release-readiness workflow recognizes:

- `APPLE_CERTIFICATE_P12_B64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_API_KEY_B64`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER`

These credentials are intentionally stored only as GitHub Actions secrets. The workflow must not claim Developer ID signing or notarization unless the corresponding signing and verification steps actually succeed.

## Release readiness

Run **Release readiness** manually for a release tag. The gate verifies release assets and SHA-256 manifests and can be configured to fail when Windows or macOS publisher-trust credentials are missing.

## Important distinction

- SHA-256 = artifact integrity
- GitHub attestation = build/provenance signal
- Authenticode / Developer ID = publisher identity and OS trust

One does not replace another.
