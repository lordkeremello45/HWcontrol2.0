# Contributing to HWControl 2.0

Thank you for contributing to HWControl 2.0.

HWControl is a cross-platform desktop hardware monitoring and control project built with Flutter/Dart, a Go bridge, and a native C++/CMake engine.

## Before opening an issue

- Search existing issues first.
- Include the operating system, architecture, HWControl version/commit, and relevant hardware.
- For hardware-related reports, include the detected CPU/GPU and driver information when available.
- Never post passwords, API keys, bridge authentication keys, signing credentials, or other secrets.

## Bug reports

A useful bug report should include:

1. What you expected to happen.
2. What actually happened.
3. Reproduction steps.
4. Platform and architecture.
5. Application version or commit.
6. Relevant logs or diagnostic output with secrets removed.

Hardware behavior can vary by motherboard, GPU, firmware, driver, kernel, and operating-system permissions. Do not assume that a GUI control means that hardware control is supported on every platform.

## Feature requests

Explain the user-facing problem and the proposed behavior. For hardware-control features, describe the target hardware/API and the safety constraints.

## Pull requests

Keep changes focused and reviewable.

Before submitting a PR, run the relevant checks where available:

```sh
# Native engine
cmake -S . -B build -DGGML_NATIVE=OFF -DGGML_CCACHE=OFF
cmake --build build --parallel 2
ctest --test-dir build --output-on-failure

# Go bridge
cd bridge_service
go test ./...
go build ./src
cd ..

# Flutter dashboard
cd gui_dashboard
flutter pub get
flutter analyze
flutter test
cd ..
```

Platform-specific changes should also be validated by the corresponding GitHub Actions workflow.

## Security issues

Do not report security vulnerabilities in a public issue. Use the repository's GitHub Security reporting mechanism and follow [SECURITY.md](SECURITY.md).

## Hardware-control changes

Safety is a release requirement. New hardware-control backends must:

- explicitly report capability;
- fail closed when a backend is unavailable;
- validate ranges and platform permissions;
- avoid pretending that monitor-only hardware supports control;
- include tests for unsupported and failure paths.

## Release and signing

Release artifacts are produced by GitHub Actions. Do not commit generated installers or signing credentials. See [docs/CODE_SIGNING_POLICY.md](docs/CODE_SIGNING_POLICY.md) for the project's signing policy.

## License

By contributing, you agree that your contribution is provided under the repository's GPLv3 license.
