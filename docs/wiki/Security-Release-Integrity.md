# Release Integrity

The release-integrity workflow validates published artifacts with:

- individual SHA-256 manifests;
- SHA-512 manifests where present;
- release-wide SHA-256SUMS.txt;
- release-wide SHA512SUMS.txt;
- release-wide SHA3-512SUMS.txt.

Optional release-manifest signatures are supported through:

- Ed25519;
- HWControl GPG.

The workflow verifies generated signatures before publishing them.

## Verification principle

A checksum verifies that the downloaded bytes match the published digest. It does not prove who authored those bytes.
