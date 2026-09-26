# HWControl 2.0 Wiki

HWControl 2.0 is an open-source, cross-platform desktop application for hardware monitoring and controlled hardware interaction.

## Project at a glance

- **UI:** Flutter / Dart
- **Secure local bridge:** Go
- **Native engine:** C++ with CMake
- **Release targets:** Windows 10/11 x64, macOS 14+ Apple Silicon, Debian/Ubuntu-family Linux x64
- **Website:** https://lordkeremello45.github.io/HWcontrol2.0/
- **Source:** https://github.com/lordkeremello45/HWcontrol2.0
- **GitLab mirror:** https://gitlab.com/lordkeremello45/HWcontrol2.0
- **Current channel:** Beta

## Current capabilities

The dashboard exposes CPU, memory, disk, GPU and fan telemetry where the operating system/driver exposes it. It also provides temperature history, configurable temperature alerts, local profiles, hardware-control commands, security status, bridge diagnostics and update checks.

Hardware-control availability is capability-driven: if a platform or device does not expose a safe supported control path, the application must remain monitor-only rather than pretending that control is available.

## Beta distribution

Platform-specific Beta release channels are maintained on GitHub:

- Windows: https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.3.0-beta-windows
- Linux: https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.3.0-beta-linux
- macOS: https://github.com/lordkeremello45/HWcontrol2.0/releases/tag/v0.3.0-beta-macos
- All releases: https://github.com/lordkeremello45/HWcontrol2.0/releases

A release is considered distributable only after its platform workflow has produced the expected package assets and checksum manifest.

## Supported operating systems

| Platform | Release target | Architecture | Primary package |
|---|---|---|---|
| Windows 10 / 11 | Beta | x64 | Guided Setup.exe + MSI + portable ZIP |
| macOS 14+ | Beta | Apple Silicon / arm64 | PKG + DMG containing HWControl.app |
| Debian / Ubuntu family | Beta | x64 | DEB + TAR.GZ / TAR.ZST |
| Other x64 Linux families | Portable package path | x64 | TAR.GZ / TAR.ZST |

## Quick start

1. Open the project website or the GitHub Beta release for your platform.
2. Download a published release asset.
3. Verify its published SHA-256 checksum.
4. Install the platform package.
5. Start HWControl and confirm that the local bridge is online.
6. Open **System status** to inspect telemetry, security and driver state.
7. If something is wrong, submit a Beta feedback report with hardware and OS details.

## Beta feedback

The feedback pipeline is:

Google Form → Google Sheets → Apps Script → GitHub Issue → GitHub Actions → GitLab mirror

The Apps Script integration:

- avoids duplicate Issue creation;
- retries transient GitHub API failures;
- tracks processing status and attempts;
- filters common contact/private fields from Issue bodies;
- uses a stable feedback ID for recovery;
- never stores the GitHub token in repository source.

Setup documentation: integrations/google-feedback/README.md.

## Public engineering / community

The project uses GitHub as the source of truth and GitLab as an automated mirror. Public technical discussion should focus on reproducible engineering problems and useful cross-platform implementation knowledge.

See:

- [Stack Overflow Topics](../community/Stack-Overflow-Topics)
- [Public Profile Checklist](../community/Public-Profile-Checklist)
- [Contributing](Development-Contributing)
- [Support](Troubleshooting)

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
