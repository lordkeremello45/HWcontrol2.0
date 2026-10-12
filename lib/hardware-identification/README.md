# HWcontrol2.0 Hardware Identification Library

Status: **initial implementation; not yet integrated into the Go bridge or release installers**.

This Windows-only C# collector is intentionally read-only. It collects OS-exposed system, BIOS, motherboard, CPU, GPU, and driver identity fields and emits one JSON document to stdout. It does not read temperatures, control fans, change clocks, or alter device configuration.

## Scope

- WMI/CIM collection for system, BIOS, motherboard, CPU, and video-controller identities.
- Multiple CPU/GPU records rather than assuming a single processor or graphics adapter.
- Offline, conservative family labels for common CPU vendors and laptop product families.
- PCI vendor/device token extraction for matching against a future curated device catalog.
- JSON schema versioning and warnings when WMI classes cannot be queried.
- No serial numbers, SMBIOS UUIDs, MAC addresses, usernames, product keys, or other stable identifiers.

The model strings reported by Windows remain the source of truth. Family labels are hints only and must not be presented as a verified exact SKU. Generic or OEM-specific WMI results are preserved rather than guessed.

## Build and test

Requires the .NET 8 SDK on Windows:

```powershell
dotnet build .\HWControl.HardwareIdentification.csproj --configuration Release
dotnet run --project .\HWControl.HardwareIdentification.csproj --configuration Release -- --self-test
dotnet run --project .\HWControl.HardwareIdentification.csproj --configuration Release
```

The normal invocation emits JSON to stdout. Diagnostics are limited to stderr/JSON warnings. This is a Windows-specific project and is not the Linux/macOS hardware collector.

## Planned integration gates

Before the Go bridge relies on this collector, the project must add a packaged, versioned helper invocation with bounded execution time, output-size limits, strict JSON validation, and a fail-closed fallback. Windows release packaging must include the helper (preferably self-contained) and smoke-test it on the packaged artifact. CI compilation alone does not prove the collector works on physical hardware.

The root `/lib` directory is intended for reusable project libraries. The initial module stays deliberately small; the overall 200 MB budget is a ceiling, not a target.
