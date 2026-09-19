# Artifact Attestation

The Windows Setup release workflow uses GitHub Actions artifact attestation for the published Setup.exe when that workflow step succeeds.

Attestation is a provenance/supply-chain signal. It does not create a Windows trusted publisher certificate and does not by itself remove SmartScreen or OS trust warnings.
