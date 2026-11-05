# Cross-platform CI

Cross-platform validation must exercise the native installer and runtime on the matching operating system. A successful compile alone is not a package smoke test.

## Windows x64

- Build Flutter, Go bridge, native engine and the MSI/Setup/portable payload.
- Validate MSI install, both Windows services, service identity, bridge TCP listener, ProgramData ACLs, provisioned integrity key, shortcuts, and uninstall cleanup.
- MSI shortcuts are machine-wide: Public Desktop and ProgramData Start Menu.
- Windows DPAPI integrity key now uses machine scope for the LocalService-hosted bridge; ProgramData ACLs remain the access boundary.
- A Windows-only DPAPI round-trip regression test was added. It does not replace the end-to-end MSI test running under LocalService.

## Linux x64

- Build and validate DEB, TAR.GZ, TAR.ZST and ZIP assets.
- Install the DEB and verify service enablement, bridge Unix socket, permissions, IPC, upgrade and removal.
- A systemd `active` state is not readiness for a `Type=simple` service. The smoke test now waits up to 30 seconds for the socket and prints `systemctl status` plus `journalctl` on timeout.

## macOS arm64

- Build PKG, DMG and app-bundle ZIP for macOS 14+ Apple Silicon.
- Validate the bridge and security-guardian LaunchDaemons, socket readiness, install/upgrade and uninstall.
- Installer scripts use the POSIX shell test builtin; both launch daemon plists are copied to the installer app root and both are stopped during upgrade.

## Gate status

The Windows, Linux and macOS recovery changes are committed, but the latest GitHub Actions runs were queued/pending at the time of this update. Do not mark any platform verified until its native install/runtime/uninstall job passes. Physical hardware control is not covered by these package smoke tests.
