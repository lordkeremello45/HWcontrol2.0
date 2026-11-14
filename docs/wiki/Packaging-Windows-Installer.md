# Windows Installer

## Release artifacts

- guided `Setup.exe` bootstrapper;
- MSI package for managed deployment;
- portable ZIP and 7Z archives;
- unsigned MSIX beta-preview artifact (not production-trusted).

The portable archives contain `HWControl.exe` and the companion bridge, security and native runtime files. The separately published `.exe` is the guided Setup installer.

## Installer stack

```text
Windows build
    ↓
Flutter Windows build + Go Bridge + C++ AI/audio helpers
    ↓
WiX MSI
    ↓
WiX Burn Setup.exe
    ↓
Install / repair / uninstall
    ↓
HWControlBridge + security guardian + dashboard + required C++ AI/audio helpers
```

## CI failure fixes

- WiX `PackageDir` and icon paths are resolved to absolute paths before the MSI build. The earlier relative path was interpreted from the WiX source directory and caused zero harvested files (`WIX8601` / `WIX8600`).
- The LocalService-hosted bridge protects its generated `verify.key` using DPAPI `CRYPTPROTECT_LOCAL_MACHINE`. Access to the blob remains restricted by the ProgramData ACL to SYSTEM, Administrators and LocalService.
- MSI install refreshes the legacy per-user key with the installation inventory. Review this integrity-baseline reset lifecycle whenever installer upgrade behavior changes.
- Smoke tests check machine-wide Public Desktop and ProgramData Start Menu shortcuts, verify their targets and icon paths, then assert uninstall cleanup.

A Windows-only DPAPI round-trip and input-validation test was added. The decisive validation is still a clean MSI install with both services running as LocalService and surviving a service restart.

## Signing

The workflow supports Authenticode signing when configured certificate secrets are present. This is independent from SignPath Foundation. Do not claim trusted publisher signing unless the released binary's signature is verified.
