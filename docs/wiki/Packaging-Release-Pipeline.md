# Release Pipeline

The release flow separates build validation, platform packaging, installer publication and release-integrity checks.

```text
Source / tag
   ↓
Platform builds
   ↓
Native tests + Flutter tests
   ↓
Package generation
   ↓
Smoke validation
   ↓
GitHub Release assets
   ↓
SHA256 / SHA512 / SHA3-512 manifests
   ↓
Optional Ed25519 / GPG release signatures
   ↓
Artifact attestation where configured
```

Windows Setup publication is handled by the Windows setup release workflow after the platform release trigger.

A release should not be described as code-signed merely because checksum or attestation metadata exists.
