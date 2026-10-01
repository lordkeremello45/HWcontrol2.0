# HWcontrol2.0 Rust Security Support

This crate is the safe boundary layer, not the security-policy authority.

Architecture:

Go Bridge
    |
    v
SPARK Security Core
    |
    | ALLOW / DENY
    v
Rust Security Support
    |
    v
C++ Hardware Engine

Rust is intentionally limited to bounded ABI representations, C/C++ FFI boundary handling, memory-safe data conversion, preserving SPARK's ALLOW/DENY result, and fail-closed handling of unknown decision values.

Rust must not override a SPARK DENY, implement a second divergent hardware-safety policy, read or persist bridge.key, perform hardware I/O, or become the source of authorization truth.

The crate is dependency-free to keep this security boundary small. The SPARK-to-Rust native link remains a separate integration step until the supported GNAT/SPARK toolchain is validated on each target platform.
