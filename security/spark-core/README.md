# HWcontrol2.0 SPARK Security Core

This directory contains the first isolated Ada/SPARK security boundary for HWcontrol2.0.

## Purpose

The core is intentionally small and policy-focused. It does not replace the Go bridge authentication implementation, cryptographic primitives, or the C++ hardware engine.

It formally specifies and verifies the fail-closed decision that precedes hardware-control execution:

- authorization must be granted;
- runtime integrity must be healthy;
- thermal telemetry must be valid;
- temperature must remain below the application critical threshold;
- fan commands are constrained to 0..100%.

Unknown or unsafe state produces Deny.

## Toolchain

The project is pinned to the stable GNAT 15.3.0 toolchain for production compatibility with the project's macOS 14+ target. GNAT 16.1.0 is newer, but its current Apple-platform support is officially focused on macOS 15/26, so it is not selected as the project baseline.

GNATprove 16.1.0 is used for formal analysis.

Alire is the dependency/toolchain manager. Keep the security core isolated from the main CMake graph until its ABI boundary is introduced and validated.

## Local validation

From this directory:

    alr build
    alr run
    alr gnatprove -P security_core.gpr --level=2

The production rule is that a security-core change is not accepted unless compilation, runtime tests, and GNATprove analysis pass.

## Integration boundary

The intended next integration step is a narrow C ABI between this core and the Go/native boundary. Cryptographic authentication remains in the existing bridge until a separately reviewed, verified implementation is available; SPARK should not be used as a branding-only replacement for proven cryptographic libraries.
