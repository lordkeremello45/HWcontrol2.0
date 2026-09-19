# Cross-platform CI

The repository contains a cross-platform package-validation workflow.

## Linux

Runs native CMake tests, Go tests, Flutter analysis/tests and builds/validates a DEB.

## Windows

Runs native CMake tests, Go tests, Flutter analysis/tests, creates the MSI and performs an install/uninstall smoke test.

## macOS

Builds and validates the Apple Silicon application/package path using a native macOS runner.

The CI model is intended to catch platform-specific packaging and runtime failures before release publication.
