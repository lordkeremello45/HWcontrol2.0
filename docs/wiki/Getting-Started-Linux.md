# Linux

## Supported target

- Debian / Ubuntu-family x64
- Other x64 Linux distributions through the portable archive path

## Package formats

- `.deb`
- `.tar.gz`
- `.tar.zst`

The installer detects the distribution family from `/etc/os-release` and chooses an asset that actually exists in the release.

## Debian / Ubuntu

The preferred package is the DEB when available and `apt-get` is available.

## Other distributions

Arch, Fedora, RHEL-family and other x64 systems use the portable archive path unless native distro metadata is published.

## System service

The portable installer can register the included `hwcontrol-bridge.service` with systemd when present.

## Verification

Use the published SHA-256 manifest before installation. SHA-512 and SHA3-512 can be checked when the corresponding release manifests are published.
