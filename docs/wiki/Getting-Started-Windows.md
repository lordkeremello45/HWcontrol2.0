# Windows

## Supported target

- Windows 10 / Windows 11
- x64 Intel/AMD
- ARM64 release packages are not currently published

## Release formats

- Guided `Setup.exe`
- `.msi` for managed/silent deployment
- Portable `.zip`

The guided bootstrapper is WiX-based and wraps the MSI-backed installation flow.

## Installer behavior

The installer provisions the dashboard, bridge service and required application files. The MSI is the single source of truth for Windows installation state.

The validation workflow also performs install/uninstall smoke testing, service checks, local bridge checks and cleanup checks.

## Scripted installer

The repository contains `installer/install.ps1`, which:

1. finds the newest stable `-windows` release;
2. selects the Setup.exe asset when available;
3. downloads the matching SHA-256 manifest;
4. verifies the artifact;
5. launches Setup.exe or falls back to MSI when appropriate.

## Bridge

The Windows bridge can run as the `HWControlBridge` Windows service. Windows currently uses the authenticated loopback TCP endpoint `127.0.0.1:8080`; a native named-pipe client is a remaining hardening step.
