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

The production baseline is GNAT 15.3.0 because HWcontrol2.0 targets macOS 14+. GNAT 16.1.0 is newer, but its current Apple-platform support is officially focused on macOS 15/26, so it is not the compatibility baseline. GNATprove 16.1.0 is used for formal analysis.

The repository does not depend on Alire for the CI trust path. CI downloads pinned upstream GNAT, GPRbuild, and GNATprove archives and verifies their SHA-256 digests before use. Alire remains supported for developer workflows when a matching toolchain is installed.

## Local validation

From this directory:

    alr build
    alr run
    alr gnatprove -P security_core.gpr --level=2

The production rule is that a security-core change is not accepted unless compilation, runtime tests, and GNATprove analysis pass.

## Integration boundary

The intended next integration step is a narrow C ABI between this core and the Go/native boundary. Cryptographic authentication remains in the existing bridge until a separately reviewed, verified implementation is available; SPARK should not be used as a branding-only replacement for proven cryptographic libraries.
