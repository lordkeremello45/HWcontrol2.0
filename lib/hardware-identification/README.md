# HWcontrol2.0 Hardware Identification Library

Status: **integrated in source; Windows release/CI verification pending**.

This Windows-only C# collector is read-only. It collects OS-exposed system, BIOS, motherboard, CPU, GPU, and driver identity fields and emits one JSON document to stdout. It does not read temperatures, control fans, change clocks, or alter device configuration.

## Scope

- WMI/CIM collection for system, BIOS, motherboard, CPU, and video-controller identities.
- Multiple CPU/GPU records rather than assuming a single processor or graphics adapter.
- Offline, conservative family labels for common CPU vendors and laptop product families.
- PCI vendor/device token extraction for matching against a future curated device catalog.
- JSON schema versioning and warnings when WMI classes cannot be queried.
- No serial numbers, SMBIOS UUIDs, MAC addresses, usernames, product keys, or other stable identifiers.

The model strings reported by Windows remain the source of truth. Family labels are hints only and must not be presented as a verified exact SKU. Generic or OEM-specific WMI results are preserved rather than guessed.

## Go Bridge integration

On Windows, the Go Bridge looks for `hwcontrol-hardware-identification.exe` next to its own executable and invokes it directly without a shell. The adapter applies:

- a 5-second process timeout;
- a 1 MiB stdout limit;
- schema/platform/status validation and collection/count bounds;
- rejection of malformed JSON, trailing JSON values, invalid core counts, and unsupported schema versions;
- output text length/control-character normalization before assigning fields.

If the helper is missing, times out, exits unsuccessfully, or returns invalid data, the bridge falls back to the existing PowerShell CIM collector with a bounded execution time. The collector only supplies identification metadata; it is not a hardware-control or telemetry interface. The current bridge data model exposes one CPU and one GPU, so it maps the first record from the C# inventory; multi-device presentation still needs a broader bridge API.

The Windows release workflow publishes the helper as a self-contained single-file `win-x64` executable, places it beside the bridge in the Windows package, and runs its offline self-test during packaging and MSI installation smoke tests. Linux and macOS continue to use their native Go identity collectors.

## Build and test

Requires the .NET 8 SDK:

```powershell
dotnet build .\HWControl.HardwareIdentification.csproj --configuration Release
dotnet run --project .\HWControl.HardwareIdentification.csproj --configuration Release -- --self-test
dotnet run --project .\HWControl.HardwareIdentification.csproj --configuration Release
dotnet publish .\HWControl.HardwareIdentification.csproj --configuration Release --runtime win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

The normal invocation emits JSON to stdout. Diagnostics are limited to stderr/JSON warnings. This is a Windows-specific project and is not the Linux/macOS hardware collector.

## Security boundary and validation status

The Go adapter enforces the fail-closed hardware-identity contract after parsing the helper's data; model strings never authorize hardware control. The Ada/SPARK package now formally specifies the corresponding schema-valid, payload-bounded, counts-valid, and status-valid decision and exports `hwcontrol_security_validate_hardware_identity`. The Windows Go binary does not yet dynamically link or invoke that exported Ada symbol; its runtime enforcement is a matching Go implementation, not a live Go-to-SPARK call. Ada/SPARK remains responsible for its separate, formally specified fan-command safety policy; it is not claimed to prove the correctness of WMI identity data.

CI can validate compilation, offline catalog tests, JSON-boundary tests, and packaged helper self-tests. Those checks do not prove that every OEM's WMI provider reports correct model data. Physical-device coverage and confirmation that the published release artifact contains the helper remain required before claiming full hardware validation.
