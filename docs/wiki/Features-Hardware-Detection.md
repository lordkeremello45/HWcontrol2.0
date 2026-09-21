# Hardware Detection

HWcontrol2.0 now exposes a normalized hardware identity view through the authenticated bridge.

## Detected information

- PC/system manufacturer, model and system version
- BIOS vendor and version
- motherboard manufacturer, model and version
- CPU manufacturer, model, architecture, physical cores and logical threads
- GPU vendor, model and driver information
- detection source and detection status

## Platform backends

- Windows: CIM/WMI via PowerShell
- Linux: DMI/sysfs/proc with optional lspci enrichment
- macOS: sysctl and ioreg

## Privacy

Hardware serial numbers are deliberately excluded from the identity model. Diagnostic output should also pass through the existing secret/path redaction layer before export.

## Status semantics

- ok: primary hardware identity was detected
- partial: the platform backend returned incomplete information
- unavailable: the platform backend could not be queried
- unsupported: no platform-specific detector is available

Detection is informational. It does not imply that fan control or any other hardware-control capability is supported on the detected device.
