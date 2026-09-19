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

### 🚀 Getting Started
- [Getting Started](Getting-Started)
- [Installation](Getting-Started-Installation)
- [Windows](Getting-Started-Windows)
- [Linux](Getting-Started-Linux)
- [macOS](Getting-Started-macOS)
- [Building from Source](Getting-Started-Building-from-Source)

### 🖥️ Features
- [Features](Features)
- [Hardware Monitoring](Features-Hardware-Monitoring)
- [CPU & GPU Temperature](Features-CPU-GPU-Temperature)
- [Fan Curve Editor](Features-Fan-Curve-Editor)
- [Real-time Hardware Graphs](Features-Real-time-Hardware-Graphs)
- [Performance / Balanced / Quiet](Features-Performance-Balanced-Quiet)
- [Game Mode](Features-Game-Mode)

### 🏗️ Architecture
- [Architecture](Architecture)
- [Application Architecture](Architecture-Application)
- [Hardware Abstraction](Architecture-Hardware-Abstraction)
- [Platform-specific Components](Architecture-Platform-specific)
- [Data Flow](Architecture-Data-Flow)

### 📦 Packaging & Distribution
- [Packaging & Distribution](Packaging-and-Distribution)
- [Windows Installer](Packaging-Windows-Installer)
- [macOS Application](Packaging-macOS-Application)
- [Linux Packages](Packaging-Linux-Packages)
- [Cross-platform CI](Packaging-Cross-platform-CI)
- [Release Pipeline](Packaging-Release-Pipeline)

### 🔐 Security & Signing
- [Security & Signing](Security-and-Signing)
- [Code Signing](Security-Code-Signing)
- [Artifact Attestation](Security-Artifact-Attestation)
- [Release Integrity](Security-Release-Integrity)
- [SignPath](Security-SignPath)

### 🧪 Testing
- [Testing](Testing)
- [Unit Tests](Testing-Unit-Tests)
- [Smoke Tests](Testing-Smoke-Tests)
- [Windows Validation](Testing-Windows-Validation)
- [Linux Validation](Testing-Linux-Validation)
- [macOS Validation](Testing-macOS-Validation)

### 🛠️ Troubleshooting
- [Troubleshooting](Troubleshooting)
- [Windows](Troubleshooting-Windows)
- [Linux](Troubleshooting-Linux)
- [macOS](Troubleshooting-macOS)
- [Hardware Detection](Troubleshooting-Hardware-Detection)

### 👨‍💻 Development
- [Development](Development)
- [Development Environment](Development-Environment)
- [Repository Structure](Development-Repository-Structure)
- [CI/CD](Development-CI-CD)
- [Contributing](Development-Contributing)

- [FAQ](FAQ)
- [Roadmap](Roadmap)
- [License](License)

## Release readiness

The repository validates native, bridge, dashboard and package paths in GitHub Actions. Windows MSI/Setup installation and cleanup are smoke-tested on Windows runners, Linux DEB installation is validated on Ubuntu, and the macOS release path is validated on a native macOS runner.

Publisher trust is a separate layer: Windows Authenticode and macOS Developer ID/notarization are only claimed when the corresponding credentials and verification steps are actually present. Checksums and GitHub artifact attestation prove integrity/provenance but do not substitute for OS-trusted publisher signing.
