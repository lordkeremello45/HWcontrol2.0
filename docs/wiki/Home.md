# HWControl 2.0 Wiki

HWControl 2.0 is an open-source, cross-platform desktop application for hardware monitoring and controlled hardware interaction.

## Project at a glance

- **UI:** Flutter / Dart
- **Secure local bridge:** Go
- **Native engine:** C++ with CMake
- **Supported release targets:** Windows 10/11 x64, macOS 14+ Apple Silicon, Debian/Ubuntu-family Linux x64
- **Website:** https://lordkeremello45.github.io/HWcontrol2.0/
- **Source:** https://github.com/lordkeremello45/HWcontrol2.0

## Current capabilities

The dashboard currently exposes CPU, memory, disk, GPU and fan telemetry where the operating system/driver exposes it. It also provides temperature history, configurable temperature alerts, local profiles, hardware-control commands, security status and update checks.

The bridge is loopback-only by default and authenticates commands with HMAC-SHA-256.

## Supported operating systems

| Platform | Release target | Architecture | Primary package |
|---|---|---|---|
| Windows 10 / 11 | Supported | x64 | Guided Setup.exe + MSI + portable ZIP |
| macOS 14+ | Supported release target | Apple Silicon / arm64 | PKG + DMG containing HWControl.app |
| Debian / Ubuntu family | Supported | x64 | DEB + TAR |
| Other x64 Linux families | Portable package path | x64 | TAR.GZ / TAR.ZST |

## Quick start

1. Open the project website.
2. Choose your operating system.
3. Download a published release asset.
4. Verify the published SHA-256 checksum.
5. Install the platform package.
6. Start HWControl and confirm that the local bridge is online.
7. Open **System status** to inspect telemetry, security and driver state.

## Documentation map

See the Getting Started, Features, Architecture, Packaging & Distribution, Security & Signing, Testing, Troubleshooting and Development sections in this repository.
