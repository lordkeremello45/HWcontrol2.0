# Unit Tests

The repository uses language-native test systems. The exact set of tests and their result must be checked against the workflow run for the commit being evaluated.

## C++ / CMake

CTest covers the separate AI, audio and Game Core components where their targets are enabled. The AI suite includes model/runtime and telemetry defensive paths; Audio Core covers its DSP/device-layer behavior; Game Core covers backend-selection and render-graph foundations.

```sh
cmake -S . -B build -DGGML_NATIVE=OFF -DGGML_CCACHE=OFF
cmake --build build --parallel 2
ctest --test-dir build --output-on-failure
```

## Go bridge

```sh
cd bridge_service
go vet ./...
go test -count=1 ./...
```

Tests cover bridge protocol/security, telemetry collectors, capability evaluation, platform adapters and feature-specific packages. Platform build tags mean a host test does not exercise every OS-specific runtime path.

## Flutter dashboard

```sh
cd gui_dashboard
flutter pub get
flutter gen-l10n
flutter analyze
flutter test --no-pub
```

Widget and service tests cover selected UI flows, bridge integration contracts, localization and local features. They do not prove physical sensor accuracy or hardware-control behavior.

## Supporting components

- Windows C# identity helper: .NET 8 build and offline self-test.
- Rust telemetry analyzer: Cargo tests.
- Ada/SPARK policy: dedicated build and formal-proof workflow; proof success does not establish end-to-end runtime integration.
- Website: Node test suite and Astro production build.

CI success is scoped to the exact commit, runner, toolchain and test commands that completed.
