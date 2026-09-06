# HWControl Installer Hub

This directory is the source-controlled entry point for the HWControl desktop installers.

## Package matrix

| Platform | Installer | Architecture | Package source |
|---|---|---|---|
| Windows | `.msi` | x64 | GitHub Release asset |
| macOS | `.pkg` / `.dmg` with `HWControl.app` | Apple Silicon / arm64 | GitHub Release asset |
| Linux | `.deb` | x64 | GitHub Release asset |

The actual binary installers are intentionally kept as GitHub Release assets rather than committed to `main`. This keeps the repository lightweight while still providing versioned, checksum-protected installers. The release workflow produces the Windows MSI, macOS PKG/DMG, and Linux DEB packages.

## Guided installation

- Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1`
- macOS: run `./install.command` from Terminal, or double-click it after allowing Terminal execution.
- Debian/Ubuntu: `./install.sh`

Each launcher resolves the latest platform-specific release, downloads the native installer, verifies the published SHA-256 asset when available, and then starts the platform installer. No downloaded application is executed silently.

## macOS application bundle

The macOS release is distributed as a signed/package-ready `HWControl.app` inside the `.pkg` installation payload and the `.dmg` distribution image. Keeping a second `.app` copy in Git would duplicate a large binary tree without improving installation reliability.

## Release requirements

A release is considered installer-complete only when it publishes:

- Windows: `.msi` and `.sha256`
- macOS: `.pkg`, `.dmg`, and `.sha256`
- Linux: `.deb` and `.sha256`

Linux packaging is intentionally not modified by the Windows/macOS installer fixes.
