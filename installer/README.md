# HWControl Installer Hub

This directory is the source-controlled entry point for the HWControl desktop installers.

## Package matrix

| Platform | Installer | Architecture | Package source |
|---|---|---|---|
| Windows | `.msi` | x64 | GitHub Release asset |
| macOS | `.pkg` / `.dmg` with `HWControl.app` | Apple Silicon / arm64 | GitHub Release asset |
| Debian / Ubuntu | `.deb` | x64 | GitHub Release asset |
| Arch / Manjaro / EndeavourOS | `.tar.zst` | x64 | GitHub Release asset |
| Fedora / RHEL / Rocky / AlmaLinux | `.tar.zst` | x64 | GitHub Release asset |
| Other x64 Linux | `.tar.zst` or `.tar.gz` | x64 | GitHub Release asset |

The actual binary installers are intentionally kept as GitHub Release assets rather than committed to `main`. This keeps the repository lightweight while still providing versioned, checksum-protected installers. The release workflow publishes the Linux `.deb`, `.tar.zst`, and `.tar.gz` packages alongside the Windows/macOS packages.

## Guided installation

- Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1`
- macOS: run `./install.command` from Terminal, or double-click it after allowing Terminal execution.
- Linux: `./install.sh`

### Linux installer behavior

`install.sh` detects the Linux distribution family from `/etc/os-release` and chooses the best package that actually exists in the latest Linux release:

1. **Debian / Ubuntu family:** use `.deb` with `apt-get` when available.
2. **Arch / Fedora / RHEL family:** prefer `.tar.zst` and install the portable bundle under `/opt/hwcontrol`.
3. **Other x64 Linux:** prefer `.tar.zst`, then `.tar.gz`.
4. **Fallback:** a `.deb` can be used only when `apt-get` is available and no archive package exists.

The archive installer also registers the included `hwcontrol-bridge.service` with systemd when present and exposes the dashboard executable as `/usr/local/bin/hwcontrol` when the release contains it. SHA-256 is verified before installation whenever the release publishes a checksum file.

This is intentionally a distro-aware installer, not a claim that HWControl has native Arch/RPM package metadata. Arch/Fedora installation uses the upstream portable archive until native `.pkg.tar.zst` / `.rpm` packages are published.

## Package selection rule

The installer never assumes that a package exists just because a distro normally uses it. It checks the actual assets in the latest `-linux` release and follows the matrix above. For example, if a release has `.deb` and `.tar.zst`, Ubuntu receives `.deb`, while Fedora/Arch receive `.tar.zst`.

## macOS application bundle

The macOS release is distributed as a signed/package-ready `HWControl.app` inside the `.pkg` installation payload and the `.dmg` distribution image. Keeping a second `.app` copy in Git would duplicate a large binary tree without improving installation reliability.

## Release requirements

A release is considered installer-complete when it publishes, as applicable:

- Windows: `.msi` and `.sha256`
- macOS: `.pkg`, `.dmg`, and `.sha256`
- Linux: `.deb`, `.tar.zst`, `.tar.gz`, and `.sha256`

The Linux build/package workflow itself remains unchanged; this installer only consumes the existing Linux release assets and selects the appropriate format at installation time.
