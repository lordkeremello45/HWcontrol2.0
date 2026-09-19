# Platform-specific Components

## Windows

- Go Windows service implementation
- Windows PnP driver information
- LibreHardwareMonitor / WMI telemetry paths
- WiX MSI/bootstrapper packaging

## Linux

- Linux sysfs / amdgpu telemetry
- systemd service packaging
- DEB and portable archive flows

## macOS

- Apple Silicon release target
- native PKG/DMG distribution
- macOS installer script

Platform-specific CI jobs build and validate the relevant targets on their native runners.
