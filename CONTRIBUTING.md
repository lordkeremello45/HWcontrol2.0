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

## Issue resolution and repository updates

For bug fixes and CI failures, use a root-cause-first workflow rather than applying the first plausible patch:

1. Reproduce the failure and inspect the complete error, failing job/step, logs, and affected code path.
2. Research documented solutions, upstream guidance, relevant specifications, and proven patterns.
3. Compare the viable solutions, including security, portability, maintainability, testability, regression risk, and release impact.
4. Eliminate approaches that mask failures, weaken validation, remove tests, suppress errors, or create unnecessary technical debt.
5. Select the most appropriate solution and consider how it can be strengthened before implementation.
6. Apply the focused fix to the repository, preferably on `main` when the change is explicitly authorized for direct main-branch maintenance.
7. Run the relevant build, unit, integration, packaging, or CI validation.
8. Inspect the resulting repository/CI state and push the validated change.
9. Document the root cause, fix, validation evidence, and any remaining blocker.

Never declare an issue resolved solely because the code changed or a workflow was edited. A fix is complete only when the relevant validation supports it.

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
