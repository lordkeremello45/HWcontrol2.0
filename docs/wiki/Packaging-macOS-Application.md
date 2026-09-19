# macOS Application

The macOS release contains `HWControl.app` inside the PKG and DMG distribution path.

The release target is Apple Silicon / arm64 on macOS 14+.

Current source-controlled installation uses `installer/install.command`, which resolves a stable release, verifies SHA-256, optionally verifies additional manifests and launches the PKG installer.

Developer ID signing and notarization are separate production trust mechanisms and require Apple credentials.
