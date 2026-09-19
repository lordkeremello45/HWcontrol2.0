# Building from Source

HWControl 2.0 uses three main components.

## Native engine

The root CMake project requires CMake 3.16+ and C++17. The build fetches a pinned llama.cpp revision through CMake FetchContent.

Typical native build:

```sh
cmake -S . -B build -DGGML_NATIVE=OFF -DGGML_CCACHE=OFF
cmake --build build
ctest --test-dir build --output-on-failure
```

## Go bridge

The bridge is in `bridge_service` and targets Go 1.22.

```sh
cd bridge_service
go test -count=1 ./...
go build -buildvcs=false -trimpath -ldflags='-s -w' -o ../bridge-service ./src
```

## Flutter dashboard

The dashboard is in `gui_dashboard`.

```sh
cd gui_dashboard
flutter pub get
flutter analyze
flutter test --no-pub
```

Platform-specific release jobs create the required Flutter platform runner files during CI.

## Model

The native project expects the Gemma GGUF model path under `ai_core/models/` unless an alternate runtime path is configured. The model is treated as a runtime input rather than being downloaded during CMake configure.
