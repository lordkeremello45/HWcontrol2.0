# Windows Validation

The Windows CI job runs on a Windows 2022 runner.

The Windows validation workflow builds the C++ components and runs CTest, tests/builds the Go bridge, builds/tests the C# hardware-identification helper, analyzes/tests the Flutter dashboard, and exercises the configured MSI/Setup install/uninstall smoke-test path. Check the current run to confirm which jobs actually completed.

The setup-release workflow additionally builds the guided Setup.exe and validates its installation path.
