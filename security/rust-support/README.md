# HWcontrol2.0 Rust Security Support

This crate is a small, dependency-free FFI support layer. It is not the security-policy authority and it does not perform hardware I/O.

## Current runtime status

The production Go bridge currently performs command authentication, fan range validation, telemetry validation and the platform capability check. The Go binary does **not** currently call the Ada/SPARK C ABI or this Rust crate. Do not treat the diagram below as the active request path.

The C-compatible SPARK library and Rust support feature are separately specified and tested. The optional `spark-ffi` feature is not enabled in the production bridge build until native linking, GNAT/SPARK toolchain availability and an end-to-end denial test are validated on each target OS.

## Intended integration boundary (not yet wired)

```text
Flutter / Dart
      |
      v
Authenticated Go Bridge
  - HMAC / nonce / replay checks
  - request decoding and validation
      |
      v
Future SPARK FFI gate
  - thermal / authorization / integrity policy
  - ALLOW / DENY
      |
      v
Go platform adapter
  - capability and permission checks
      |
      v
OS / vendor API / hardware
```

Rust is optional FFI support for the future native call boundary. Its responsibilities are limited to bounded ABI representations, memory-safe data conversion, preserving the SPARK ALLOW/DENY result, and failing closed for unknown decision values.

Rust must not override a SPARK DENY, implement a second divergent hardware-safety policy, read or persist `bridge.key`, perform hardware I/O, or become the source of authorization truth.

The project hardware runtime currently lives in the Go bridge. A shared C++ Hardware Engine / Cooling HAL remains a target architecture; it is not called by this Rust crate.
