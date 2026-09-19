# Installation

HWControl release artifacts are distributed through GitHub Releases.

## Before installation

Verify the downloaded artifact against its published SHA-256 checksum. Additional SHA-512 and SHA3-512 manifests may also be available.

Checksums provide artifact integrity. They do not replace OS-trusted publisher signatures.

## Platform paths

| Platform | Recommended path |
|---|---|
| Windows | Guided Setup.exe |
| macOS | PKG / DMG containing HWControl.app |
| Debian / Ubuntu | DEB |
| Other supported x64 Linux | TAR.GZ / TAR.ZST |

The repository also contains small platform installer scripts that resolve the latest stable release and verify its checksum before launching installation.

## After installation

Confirm:

- the application starts;
- the dashboard can connect to the bridge;
- **BRIDGE ONLINE** is shown;
- telemetry values are populated where supported;
- the System status panel reports the expected sensor/driver state.

## Safety

Hardware-control features are bounded by application validation and the availability of the platform-specific backend. A dashboard control being visible does not imply that every machine can execute that operation.
