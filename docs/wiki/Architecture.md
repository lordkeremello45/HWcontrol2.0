# Architecture

The current hardware-monitoring and control runtime is a Flutter/Dart desktop dashboard connected to an authenticated localhost Go bridge. The Go bridge owns telemetry collection, hardware identity integration, capability reporting, safety checks and the platform-specific control adapters.

C++/CMake components are separate native helpers for local AI, audio processing and the early Game Core foundation. They are not a shared hardware-control engine. Ada/SPARK and Rust components provide selected security-policy/FFI support; end-to-end use of SPARK across every production command path is not yet verified.

See [Current Implementation Status](../CURRENT-IMPLEMENTATION-STATUS.md) for implementation and validation boundaries.

- [Application Architecture](Architecture-Application.md)
- [Hardware Abstraction](Architecture-Hardware-Abstraction.md)
- [Platform-specific Components](Architecture-Platform-specific.md)
- [Data Flow](Architecture-Data-Flow.md)
- [Game Core Architecture](Architecture-Game-Core.md)
- [Logical Service Architecture](Architecture-Six-Services.md)
