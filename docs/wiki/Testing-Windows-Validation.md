# Windows Validation

The Windows CI job runs on a Windows 2022 runner.

It builds the native engine, runs CTest, tests/builds the Go bridge and Flutter dashboard, creates the MSI and performs a complete install/uninstall smoke test.

The setup-release workflow additionally builds the guided Setup.exe and validates its installation path.
