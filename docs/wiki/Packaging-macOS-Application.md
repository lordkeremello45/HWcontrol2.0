# macOS Application

## Release artifacts

The Apple Silicon / arm64 release target is macOS 14+ and contains:
- PKG installer;
- DMG disk image;
- app-bundle ZIP containing `HWControl.app` and its companion runtime files.

`HWControl.app` is a directory bundle, not a standalone file extension. The DMG and app-bundle ZIP are the downloadable files.

## Installer lifecycle

The source-controlled installer resolves a release, verifies SHA-256, optionally verifies additional manifests, and launches the PKG installer.

The package installs both the bridge and security-guardian LaunchDaemons. The postinstall script uses POSIX shell built-ins, and the preinstall script stops/removes both daemons before an upgrade. The smoke test waits for the bridge socket and emits installer/launchd logs if readiness times out.

## Trust and verification

Developer ID signing and notarization are separate production trust mechanisms and require Apple credentials. Package generation and successful installation on a GitHub runner do not prove signing, notarization, hardware telemetry or fan-control support.
