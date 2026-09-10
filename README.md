# HWcontrol2.0

[![HWControl Website](https://img.shields.io/badge/HWControl-Website-111827?style=for-the-badge&logo=googlechrome&logoColor=white)](https://lordkeremello45.github.io/HWcontrol2.0/)
[![GitHub Releases](https://img.shields.io/github/v/release/lordkeremello45/HWcontrol2.0?display_name=tag&style=for-the-badge)](https://github.com/lordkeremello45/HWcontrol2.0/releases)

HWControl 2.0 is a high-performance, kernel-level hardware management and control suite designed for precision and stability. Built with a focus on low-latency communication and secure system interaction, this project provides a robust bridge between user-space applications and kernel-mode operations.

## Supported operating systems

| Platform | Supported target | Release format | Architecture | Status |
|---|---|---|---|---|
| Windows | Windows 10 / Windows 11 | Guided `Setup.exe` + `.msi` + portable `.zip` | x64 | Supported |
| macOS | macOS 14 Sonoma and newer release targets | `.pkg` + `.dmg` containing `.app` | Apple Silicon / arm64 | Supported |
| Linux | Debian/Ubuntu-family x64 targets | `.deb` + `.tar.gz` / `.tar.zst` | x64 | Supported |

> **OS compatibility note:** Windows releases are currently packaged for 64-bit Intel/AMD systems. Windows ARM64 is not shipped as a release package. macOS releases are currently built and validated on Apple Silicon; an Intel (`x86_64`) macOS package is not provided. The macOS package is currently built on a macOS 14 runner, so macOS 14+ is the supported release target. Linux packaging remains x64 and is unchanged by the Windows/macOS installer fixes.

## Installer hub

The `installer/` directory is the source-controlled installer entry point. It contains the platform installer launchers and documentation, while the large releasable binaries remain GitHub Release assets instead of inflating the Git repository. The Windows release provides a guided `Setup.exe` for normal users, the `.msi` for enterprise/IT deployment, and a portable `.zip` for advanced users. macOS and Linux keep their native package formats.

For users who want the graphical application bundle on macOS, the `.app` is included in the macOS package/DMG; it is not maintained as a second copy in Git.

## Windows installation

The recommended Windows path is the guided `HWControl-...-Setup.exe`. It installs the MSI-backed product, lets the user choose the installation directory, requests elevation when needed, and preserves a single source of truth for the Windows service, security key provisioning, dashboard, and AI engine. The standalone `.msi` remains available for silent/managed deployment, while the portable `.zip` is intentionally kept for users who do not want an installed Windows service.

## Bridge diagnostics

The local bridge exposes a signed `Get Diagnostics` command alongside `Get Status` and `Get Security`. The diagnostics snapshot reports the bridge version, operating system/architecture, Go runtime, key-file location and configuration state, model presence/digest, sensor and GPU-driver state, loopback listen address, uptime, and whether the current build includes the hardware-control backend.

The bridge remains loopback-only (`127.0.0.1`) and requires the existing HMAC authentication for diagnostics, so diagnostic data is not exposed as an unauthenticated network endpoint.

## Code signing policy

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

HWControl 2.0 is preparing an application for the SignPath Foundation Open Source Code Signing program. The intended signing scope is the Windows release artifacts produced by the repository's GitHub Actions workflows, including the guided `Setup.exe`, `.msi`, and applicable Windows executable artifacts.

Signing is not considered active until the project is accepted, the trusted GitHub build integration is configured, and a signed release artifact has been successfully verified. Release signing must use artifacts built from this repository and must not use manually uploaded local binaries.

- **Committers and reviewers:** `lordkeremello45`
- **Approver:** `lordkeremello45`
- **Policy:** [`docs/CODE_SIGNING_POLICY.md`](docs/CODE_SIGNING_POLICY.md)
- **Privacy/security:** [`SECURITY.md`](SECURITY.md)

## Website

The official project website provides the platform-specific installer selector and dynamically resolves the latest GitHub Release assets:

**https://lordkeremello45.github.io/HWcontrol2.0/**

## Architecture

The project is built on a multi-layer architecture:

**ai_core (C++):** The heart of the system, handling kernel-mode drivers and hardware-level operations.

**bridge_service (Go):** A high-concurrency service that manages the secure communication bridge between the kernel-core and the UI.

**gui_dashboard (Dart/Flutter):** A responsive and intuitive dashboard for real-time hardware monitoring and configuration.

## Key Features

**Kernel-Level Control:** Direct interaction with hardware drivers for maximum efficiency.

**BSOD Shield:** Built-in safeguards to prevent system instability and kernel panics.

**Secure Communication:** Implements SHA-256 verification to ensure the integrity of driver modules.
