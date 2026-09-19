# Smoke Tests

Smoke tests validate that a built package behaves like an installable product.

The Windows path includes:

- MSI generation;
- silent installation;
- installed-file checks;
- Windows service state;
- HWCONTROL_KEY provisioning;
- bridge listen check on 127.0.0.1:8080;
- uninstall;
- cleanup verification.

Linux validates the built DEB and expected installed executables.

macOS uses its native packaging/validation workflow.
