# Windows Installer

The Windows release path contains:

- guided `Setup.exe` bootstrapper;
- MSI package;
- portable ZIP.

## Installer stack

```text
Windows build
    ↓
Flutter Windows build
    ↓
WiX MSI
    ↓
WiX Burn Setup.exe
    ↓
Install / repair / uninstall
    ↓
HWControlBridge + dashboard + native engine
```

The workflow smoke-tests MSI installation and uninstallation, service state, bridge port, provisioned bridge key and cleanup.

## Signing

The current workflow supports Authenticode signing when the configured Windows certificate secrets are present. This is independent from SignPath Foundation and should not be described as active unless a release contains a verified trusted publisher signature.
