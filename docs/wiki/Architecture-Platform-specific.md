# Platform-specific Components

This page documents the current implementation, not merely the target support matrix.

## Windows 10/11 x64

- Authenticated local Go bridge service.
- PowerShell CIM/WMI collection for hardware identity and selected sensors.
- Optional LibreHardwareMonitor WMI namespace for additional sensor readings.
- C# helper for read-only CPU/GPU/system identity, with a PowerShell fallback.
- Fan writes remain monitor-only; no validated OEM/EC, NVAPI, ADLX or IGCL write adapter is currently wired into the bridge.
- Windows setup/MSI/ZIP/7Z and MSIX preview packaging are defined in release workflows.

Vendor SDKs provide real APIs, but using one requires vendor/device capability discovery, explicit user consent, bounded commands, readback, reset-to-firmware behavior and an actual hardware matrix. SDK availability does not establish HWcontrol integration.

## Linux x64

- Authenticated Unix-domain Go bridge.
- gopsutil, Linux hwmon, amdgpu sysfs and NVIDIA `nvidia-smi` telemetry.
- Linux hwmon PWM channels are discovered independently. A channel becomes writable only with a matching RPM sensor, writable PWM file and existing manual mode (`pwmN_enable=1`).
- Before each write, the bridge rechecks manual mode and validates the PWM value readback.
- Optional externally installed liquidctl CLI for read-only USB cooling telemetry.
- systemd service and DEB/portable archive packaging.

## macOS 14+ Apple Silicon

- Authenticated local Go bridge using Unix-domain IPC.
- Hardware identity from `sysctl` and `ioreg`.
- Shared telemetry collectors only where the OS exposes compatible data.
- Fan writes remain unavailable pending a documented, supported and physically validated API. Private SMC protocol emulation is not used.
- PKG/DMG/app-bundle release workflows target Apple Silicon.

## Validation boundary

A successful cross-compilation or CI package job proves a build/package path, not hardware compatibility. Real sensor availability, fan control, AIO support, permission handling, install/launch/cleanup and physical fail-safe behavior must be validated per operating system and hardware family.
