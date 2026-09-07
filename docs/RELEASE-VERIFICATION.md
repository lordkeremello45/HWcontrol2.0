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

## 3. SHA3-512

Each verified release also receives `SHA3-512SUMS.txt`. SHA3-512 is based on the SHA-3/Keccak sponge construction and gives a structurally different integrity algorithm from SHA-256/SHA-512.

Linux/macOS with OpenSSL 3:

```bash
openssl dgst -sha3-512 -r HWControl-<package>.zip
```

Then compare the digest with the corresponding entry in `SHA3-512SUMS.txt`.

Windows with a current OpenSSL installation:

```powershell
openssl dgst -sha3-512 -r .\HWControl-<package>.zip
```

SHA3-512 is an additional integrity layer, not a publisher signature.

## 4. Linux GPG release signature

Linux releases can publish a detached OpenPGP signature for the release-wide `SHA256SUMS.txt` manifest:

- `SHA256SUMS.txt.asc` — detached ASCII-armored GPG signature.
- `HWControl-GPG-public.asc` — public signing key included with the release for convenience.
- `HWControl-GPG-fingerprint.txt` — signer fingerprint published with the release.

The project trust anchor is the primary-key fingerprint:

```text
12DCBEC4A22481A8DBACA6956F1C5F7B37229F37
```

Identity:

```text
HWControl Release (Release Signing) <release@hwcontrol.dev>
```

The canonical public key is also committed to the repository as `HWControl-GPG-public.asc`, and the canonical fingerprint is published in `HWControl-GPG-fingerprint.txt`. The Linux installer pins this fingerprint and verifies the repository public key before accepting a release signature.

Manual verification:

```bash
GNUPGHOME="$(mktemp -d)"
chmod 700 "$GNUPGHOME"
gpg --batch --import HWControl-GPG-public.asc
fingerprint="$(GNUPGHOME="$GNUPGHOME" gpg --batch --with-colons --fingerprint 12DCBEC4A22481A8DBACA6956F1C5F7B37229F37 | awk -F: '$1 == "fpr" {print $10; exit}')"
test "$fingerprint" = "12DCBEC4A22481A8DBACA6956F1C5F7B37229F37"
GNUPGHOME="$GNUPGHOME" gpg --batch --verify SHA256SUMS.txt.asc SHA256SUMS.txt
rm -rf "$GNUPGHOME"
```

A successful `gpg --verify` proves that the manifest was signed by the imported key. The fingerprint comparison is what binds that key to the HWControl signer identity; do not treat a public key downloaded only from the same release as an independent trust anchor. GnuPG recommends obtaining the signer certificate through a trusted channel and comparing its fingerprint before accepting a signature.

The Linux installer performs this check automatically when `SHA256SUMS.txt.asc` is published. If a signed release is encountered and `gpg` is unavailable, installation is blocked rather than silently skipping the publisher-signature layer. Older unsigned releases remain compatible until they publish the GPG signature asset.

### GitHub Actions signing key

The private GPG key is stored only as the GitHub Actions repository secret `HWCONTROL_GPG_PRIVATE_KEY_B64`; its passphrase is stored separately as `HWCONTROL_GPG_PASSPHRASE`. The workflow imports the key, verifies the expected fingerprint, signs `SHA256SUMS.txt`, verifies the detached signature, and publishes only the public key and signature. GitHub recommends keeping sensitive values in Actions secrets and avoiding passing secrets on command lines.

The private key and passphrase must never be committed to the repository, release assets, installer, or workflow logs.

## 5. Ed25519 manifest signature

When the repository secret `ED25519_PRIVATE_KEY_B64` is configured, the release-integrity workflow signs the release-wide `SHA256SUMS.txt` with Ed25519 and publishes:

- `SHA256SUMS.txt.sig` — detached Ed25519 signature.
- `SHA256SUMS.txt.pub` — corresponding public key in PEM/SPKI format.

The private key is never published. The workflow performs a signature verification before uploading the signature.

Verify the signature with OpenSSL 3:

```bash
openssl pkeyutl -verify -rawin -pubin \
  -inkey SHA256SUMS.txt.pub \
  -in SHA256SUMS.txt \
  -sigfile SHA256SUMS.txt.sig
```

**Important:** a public key downloaded from the same release is useful for consistency checking, but it is not an independent trust anchor. For real signer authentication, pin the expected public-key fingerprint through a trusted channel and compare it before accepting the signature.

### Generate the long-lived signing key

Generate the Ed25519 key pair on a trusted machine. Never commit the private key:

```bash
openssl genpkey -algorithm ED25519 -out hwcontrol-release-ed25519.pem
openssl pkey -in hwcontrol-release-ed25519.pem -pubout -out hwcontrol-release-ed25519.pub
```

Create the GitHub Actions secret from the base64-encoded private PEM. On Linux:

```bash
base64 -w0 hwcontrol-release-ed25519.pem
```

Store the resulting value as the repository secret `ED25519_PRIVATE_KEY_B64`. Keep the private PEM offline/secure and use the same key for future releases so the signer identity remains stable.

## 6. GitHub artifact attestations

Build workflows publish GitHub artifact attestations for the release packages. The release build workflow grants the required `id-token` and `attestations` permissions and uses GitHub's attestation action for the generated packages.

Where an attestation is available, verify the artifact with the GitHub CLI:

```bash
gh attestation verify HWControl-<package> -R lordkeremello45/HWcontrol2.0
```

An attestation provides build provenance tied to the GitHub Actions workflow and repository context. It is not the same thing as a GPG signer identity, an Ed25519 signer identity, Windows Authenticode, or Apple Developer ID signature.

## 7. Publisher signatures

OS-trusted publisher signatures remain a separate layer:

- Windows: Authenticode certificate and, for production kernel drivers, the applicable Microsoft signing/attestation process.
- macOS: Developer ID Application/Installer plus Apple notarization.

Unsigned Windows artifacts must never be presented as publisher-signed merely because their SHA-256, SHA-512, SHA3-512, GPG, Ed25519, or GitHub attestation checks pass.

## Trust model

```text
Downloaded artifact
       |
       +--> SHA-256 match ---------> integrity
       |
       +--> SHA-512 match ---------> independent integrity
       |
       +--> SHA3-512 match --------> independent integrity
       |
       +--> GPG signature ----------> Linux release-manifest authenticity*
       |
       +--> Ed25519 signature -----> release-manifest authenticity*
       |
       +--> GitHub attestation ----> build provenance
       |
       +--> OS publisher signature -> publisher/OS trust

* Requires a trusted/pinned public-key fingerprint.
```

The layers answer different questions:

- **Hashes:** Did the downloaded bytes change?
- **GPG:** Was the Linux release manifest signed by the expected HWControl OpenPGP key?
- **Ed25519:** Was the release manifest signed by the expected private signing key?
- **GitHub attestation:** Was the artifact produced by the expected GitHub Actions build provenance?
- **OS signature:** Does the operating system recognize the publisher identity?

No checksum, attestation, GPG signature, or Ed25519 signature bypasses Windows SmartScreen, Windows Protected View, macOS Gatekeeper, or other OS trust decisions.

## Private key policy

Private signing keys must never be committed to this repository, included in release assets, or printed in workflow logs. Store the GPG private key and passphrase only in protected GitHub Actions secrets. Store the Ed25519 private key only in a protected signing environment/GitHub Actions secret. Rotate a signing key if compromise is suspected and publish the new public-key fingerprint through a trusted channel.
