# HWControl 2.0 Wiki

HWcontrol2.0 is an open-source Beta desktop application for hardware monitoring, diagnostics and capability-gated control. This wiki describes the current repository implementation and marks partial or unavailable functionality explicitly.

## Project at a glance

- **UI:** Flutter / Dart
- **Secure local bridge:** Go
- **Hardware collection/control:** Go bridge with OS/vendor adapters
- **Native helpers:** C++/CMake AI and audio components
- **Release targets:** Windows 10/11 x64, macOS 14+ Apple Silicon, Debian/Ubuntu-family Linux x64
- **Website:** https://lordkeremello45.github.io/HWcontrol2.0/
- **Source:** https://github.com/lordkeremello45/HWcontrol2.0
- **GitLab mirror:** https://gitlab.com/lordkeremello45/HWcontrol2.0
- **Current channel:** Beta

For a consolidated implementation snapshot, see [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md). The [physical hardware validation matrix](../HARDWARE-VALIDATION-MATRIX.md) remains the authority for device-level evidence.

## Current capabilities

The dashboard exposes CPU, memory, storage, GPU, fan and battery telemetry where the operating system/driver exposes it. It also includes local telemetry history and CSV export, hardware identity, temperature alerts, Smart Fan curves and automation, Game Mode process detection/profile assignment, Healthy Core thermal-condition indicators, optional local Gemma analysis, a CPU-only benchmark, audio tooling and offline aim practice. Hardware-control commands remain capability-gated. Battery capacity estimates are not battery-life predictions; Healthy Core is not a silicon-wear estimate; AI is advisory only.

Hardware-control availability is capability-driven: if a platform or device does not expose a safe supported control path, the application must remain monitor-only rather than pretending that control is available. An optional externally installed liquidctl CLI can provide read-only coolant/pump/fan telemetry; no pump or AIO control is implied. Windows and macOS fan writes are unavailable; Linux PWM writes are limited to channels that satisfy the bridge's RPM, writable-path and manual-mode checks.

## Beta distribution

Unified cross-platform Beta releases are published only after Windows, Linux and macOS package sets and checksum manifests pass validation:

- Windows: https://github.com/lordkeremello45/HWcontrol2.0/releases
- Linux: https://github.com/lordkeremello45/HWcontrol2.0/releases
- macOS: https://github.com/lordkeremello45/HWcontrol2.0/releases
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

Setup documentation: [Google feedback automation](https://github.com/lordkeremello45/HWcontrol2.0/tree/main/integrations/google-feedback).

## Public engineering / community

The project uses GitHub as the source of truth and GitLab as an automated mirror. Public technical discussion should focus on reproducible engineering problems and useful cross-platform implementation knowledge.

See:

- [Stack Overflow Topics](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/docs/community/Stack-Overflow-Topics.md)
- [Public Profile Checklist](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/docs/community/Public-Profile-Checklist.md)
- [Contributing](Development-Contributing.md)
- [Support](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/SUPPORT.md)

## Documentation map

### 🚀 Getting Started
- [Getting Started](Getting-Started.md)
- [Installation](Getting-Started-Installation.md)
- [Windows](Getting-Started-Windows.md)
- [Linux](Getting-Started-Linux.md)
- [macOS](Getting-Started-macOS.md)
- [Building from Source](Getting-Started-Building-from-Source.md)

### 🖥️ Features
- [Features](Features.md)
- [Hardware Monitoring](Features-Hardware-Monitoring.md)
- [CPU & GPU Temperature](Features-CPU-GPU-Temperature.md)
- [Fan Curve Editor](Features-Fan-Curve-Editor.md)
- [Real-time Hardware Graphs](Features-Real-time-Hardware-Graphs.md)
- [Performance / Balanced / Quiet](Features-Performance-Balanced-Quiet.md)
- [Performance Mode Research and Implementation Plan](Features-Performance-Mode.md)
- [Game Mode](Features-Game-Mode.md)
- [Battery Health and Capacity](Features-Battery-Health.md)
- [Healthy Core](Features-Healthy-Core.md)
- [Liquid Cooling](Features-Liquid-Cooling.md)
- [CPU Benchmark](Features-Benchmark.md)
- [Local AI Core](Features-AI-Core.md)
- [Offline Piper TTS](Features-Accessibility-and-Piper-TTS.md)
- [Audio Controller Studio](../AUDIO-CONTROLLER-STUDIO.md)

### 🏗️ Architecture
- [Architecture](Architecture.md)
- [Application Architecture](Architecture-Application.md)
- [Hardware Abstraction](Architecture-Hardware-Abstraction.md)
- [Platform-specific Components](Architecture-Platform-specific.md)
- [Data Flow](Architecture-Data-Flow.md)

### 📦 Packaging & Distribution
- [Packaging & Distribution](Packaging-and-Distribution.md)
- [Windows Installer](Packaging-Windows-Installer.md)
- [macOS Application](Packaging-macOS-Application.md)
- [Linux Packages](Packaging-Linux-Packages.md)
- [Cross-platform CI](Packaging-Cross-platform-CI.md)
- [Release Pipeline](Packaging-Release-Pipeline.md)

### 🔐 Security & Signing
- [Security & Signing](Security-and-Signing.md)
- [Code Signing](Security-Code-Signing.md)
- [Artifact Attestation](Security-Artifact-Attestation.md)
- [Release Integrity](Security-Release-Integrity.md)
- [SignPath](Security-SignPath.md)

### 🧪 Testing
- [Testing](Testing.md)
- [Unit Tests](Testing-Unit-Tests.md)
- [Smoke Tests](Testing-Smoke-Tests.md)
- [Windows Validation](Testing-Windows-Validation.md)
- [Linux Validation](Testing-Linux-Validation.md)
- [macOS Validation](Testing-macOS-Validation.md)

### 🛠️ Troubleshooting
- [Troubleshooting](Troubleshooting.md)
- [Windows](Troubleshooting-Windows.md)
- [Linux](Troubleshooting-Linux.md)
- [macOS](Troubleshooting-macOS.md)
- [Hardware Detection](Troubleshooting-Hardware-Detection.md)

### 👨‍💻 Development
- [Development](Development.md)
- [Development Environment](Development-Environment.md)
- [Repository Structure](Development-Repository-Structure.md)
- [CI/CD](Development-CI-CD.md)
- [Contributing](Development-Contributing.md)

- [FAQ](FAQ.md)
- [Roadmap](Roadmap.md)
- [License](License.md)

## Release readiness

GitHub Actions contains native, bridge, dashboard, cross-platform packaging and smoke-test workflows. Check the latest workflow run and release assets before relying on a result; workflow definitions alone do not prove that a particular run passed. CI runners do not replace physical hardware validation.

Publisher trust is a separate layer: Windows Authenticode and macOS Developer ID/notarization are only claimed when the corresponding credentials and verification steps are present and verified for the specific artifact. Checksums and GitHub artifact attestation do not substitute for OS-trusted publisher signing.

- [Advanced Control and Automation](Features-Advanced-Control.md)
- [Hardware Benchmark](Features-Benchmark.md)
- [Extension API](Features-Extension-API.md)
