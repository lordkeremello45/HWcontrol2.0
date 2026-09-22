# macOS

## Supported target

- macOS 14 Sonoma and newer release targets
- Apple Silicon / arm64
- Intel macOS packages are not currently published

## Release formats

- `.pkg`
- `.dmg` containing `HWControl.app`

## Installer

The repository contains `installer/install.command`. It:

1. resolves the newest stable `-macos` release;
2. selects a PKG asset;
3. downloads its SHA-256 manifest;
4. verifies the PKG;
5. checks optional SHA-512 and SHA3-512 manifests when available;
6. launches the native macOS installer.

## Bridge IPC

macOS uses the Unix domain socket `/Library/Application Support/HWControl/bridge.sock` by default. The socket directory is restricted to the logged-in desktop user and the bridge service.

## Build note

Current release validation uses a macOS 14 runner and Apple Silicon target. Developer ID signing and notarization require Apple-issued credentials and should only be claimed when actually present in the release.
