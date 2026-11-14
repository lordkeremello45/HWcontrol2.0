# Development Environment

Install only the toolchains required for the component you are building. CI workflows are the authoritative source for the exact runner images and pinned action versions.

## Core desktop stack

- Git
- CMake 3.16+
- C++17 compiler for ai_core/audio_core
- C++20 compiler for hw_game_core
- Go version declared by bridge_service/go.mod (currently Go 1.22)
- Flutter/Dart version pinned by the repository CI workflow
- Platform-native SDK/tooling for the target package

## Supporting components

- .NET 8 SDK for the Windows-only hardware-identification helper
- Rust stable toolchain for tools/telemetry-analyzer and optional security FFI support
- GNAT/SPARK toolchain for formal policy build/proof workflows
- Node.js/npm for the Astro website and its tests
- liquidctl is an optional external runtime dependency for read-only cooling telemetry; it is not required to build the core desktop application
- Gemma GGUF weights and Piper executable/model files are optional runtime assets and are not committed as source

## Build discipline

Read the affected CI workflow before changing a dependency or toolchain version. Keep local builds aligned with CI, retain lockfiles where the package manager uses them, and do not assume a component is part of every platform package.

See [Building from Source](Getting-Started-Building-from-Source.md) and [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md).
