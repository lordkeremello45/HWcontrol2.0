# HWcontrol2.0 SPARK Security Core

This directory contains the isolated Ada/SPARK security boundary for HWcontrol2.0.

## Purpose

The core is intentionally small and policy-focused. It does not replace the Go bridge authentication implementation, cryptographic primitives, or the C++ hardware engine.

It formally specifies and verifies the fail-closed decision that precedes hardware-control execution:

- authorization must be granted;
- runtime integrity must be healthy;
- thermal telemetry must be valid;
- sensor temperature must be inside the accepted sensor domain (-40°C..125°C);
- temperature must remain below the application critical threshold (95°C);
- typed fan commands are constrained to 0..100%;
- raw fan values crossing a foreign-language ABI are explicitly range-checked before allowing control.

Unknown, malformed, out-of-domain, or unsafe state produces Deny.

## Verification model

The security boundary is deliberately expressed as pure functions with Global => null, making the policy deterministic and free of hidden mutable state.

The proof obligations cover:

1. sensor-domain validation;
2. thermal safety;
3. typed fan command decisions;
4. raw integer fan command validation suitable for a future C ABI;
5. fail-closed authorization and integrity checks.

The raw-input validator is important for cross-language integration: C/C++/Go callers must not be able to bypass the 0..100 fan range simply because an Ada subtype would reject an invalid value before entering a typed function.

## Toolchain

The production baseline is GNAT 15.3.0 because HWcontrol2.0 targets macOS 14+. GNATprove 16.1.0 is currently used for formal analysis in CI. The exact compiler/prover compatibility is validated by CI rather than assumed.

The repository does not depend on Alire for the CI trust path. CI downloads pinned upstream GNAT, GPRbuild, and GNATprove archives and verifies their SHA-256 digests before use. Alire remains supported for developer workflows when a matching toolchain is installed.

## Local validation

From this directory:

    alr build
    alr run
    alr gnatprove -P security_core.gpr --mode=all --proof-warnings=on --level=2

The production rule is that a security-core change is not accepted unless compilation, runtime tests, and GNATprove analysis pass.

## Integration boundary

The intended next integration step is a narrow C ABI between this core and the Go/native boundary. Cryptographic authentication remains in the existing bridge until a separately reviewed, verified implementation is available; SPARK should not be used as a branding-only replacement for proven cryptographic libraries.


## Native boundary

The SPARK package now exports hwcontrol_security_validate_fan_command with a C-compatible ABI. The exported function delegates to the same formally specified Validate_Raw_Fan_Command policy; it does not create a second security policy.

The Rust support layer at security/rust-support/ can call this symbol behind its spark-ffi feature. Rust only carries and validates the ALLOW/DENY result and fails closed for unknown decision values.

The live Go/C++ integration remains intentionally gated until the GNAT/SPARK toolchain and native linking are validated on Windows 10/11, Linux x64, and macOS 14+ Apple Silicon.