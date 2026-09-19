# Linux Packages

The Linux release supports a DEB plus portable archive formats.

## Package selection

- Debian/Ubuntu: prefer `.deb`
- Arch/Fedora/RHEL-family: prefer `.tar.zst`
- other x64 Linux: `.tar.zst` or `.tar.gz`

The installer chooses from assets actually published in the release rather than assuming a distro-specific package exists.

## Native package metadata

The current portable archive path is not a claim of native Arch RPM package metadata. Native distro package formats can be added independently.
