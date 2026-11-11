# HWcontrol2.0 SPARK Security Core

This directory contains an isolated Ada/SPARK policy package for HWcontrol2.0.

## Purpose and runtime boundary

The core formally specifies and verifies selected fail-closed policy functions. It does not replace Go bridge authentication, cryptographic primitives or the current Go platform adapters.

**Runtime status:** the production Go bridge does not yet dynamically link or invoke the exported SPARK C ABI for every hardware-control command. The bridge currently enforces its own matching validation rules. The SPARK package is a separately built/tested policy boundary until native linking and an end-to-end invocation test are complete on each target OS.

The intended policy gate evaluates:

- authorization;
- runtime integrity;
- valid thermal telemetry and sensor domain (-40°C..125°C);
- temperature below the application critical threshold (95°C);
- fan command range **20..100%** (aligned with the Go bridge and dashboard);
- raw command values crossing a foreign-language ABI.

Unknown, malformed, out-of-domain or unsafe state produces Deny.

## Verification model

The security boundary is expressed as pure functions with `Global => null`, making the policy deterministic and free of hidden mutable state.

The proof obligations cover:

1. sensor-domain validation;
2. thermal safety;
3. typed fan command decisions;
4. raw integer fan command validation suitable for a future C ABI;
5. fail-closed authorization and integrity checks.

The raw-input validator is important for cross-language integration: C/C++/Go callers must not be able to bypass the fan range simply because an Ada subtype would reject an invalid value before entering a typed function.

## Toolchain

The production baseline is GNAT 15.3.0 because HWcontrol2.0 targets macOS 14+. GNATprove 16.1.0 is currently used for formal analysis in CI. Exact compiler/prover compatibility is validated by CI rather than assumed.

The repository does not depend on Alire for the CI trust path. CI downloads pinned upstream GNAT, GPRbuild and GNATprove archives and verifies SHA-256 digests before use. Alire remains supported for developer workflows when a matching toolchain is installed.

## Local validation

From this directory:

```sh
alr build
alr run
alr gnatprove -P security_core.gpr --mode=all --proof-warnings=on --level=2
```

A security-core change is not accepted unless compilation, runtime tests and GNATprove analysis pass.

## Native boundary

The SPARK package exports `hwcontrol_security_validate_fan_command` and `hwcontrol_security_validate_hardware_identity` C-compatible entry points. The fan policy constrains the value to 20..100 and requires valid telemetry, a safe temperature, healthy integrity and authorization.

The Rust support crate can call the fan validator behind its `spark-ffi` feature. Rust only carries and validates the ALLOW/DENY result and fails closed for unknown decision values. The production Go bridge does not yet invoke this ABI; the native toolchain and end-to-end path remain explicit integration work.

## Hardware identity data boundary

The C# Windows collector is an untrusted, read-only metadata source. Its JSON is not an authorization token and must never make a fan-control decision. The SPARK contract `Validate_Hardware_Identity` accepts four already-derived validation facts:

- `Schema_Valid`: supported schema version and Windows platform;
- `Payload_Bounded`: output size and every text field fit configured limits;
- `Counts_Valid`: CPU/GPU collection sizes and core/device counts are in range;
- `Status_Valid`: collector status is one of the explicitly supported states.

Any false fact yields `Deny`. The exported C ABI requires each flag to be exactly 1; unknown flag values fail closed. These checks validate whether metadata may enter the application data model, not whether the reported hardware identity is true, and they do not authorize hardware control.

The Windows Go adapter currently applies its own fail-closed input contract after parsing the helper JSON. The exported SPARK ABI is not yet dynamically linked or invoked by the Go Windows binary; do not describe this as a live Go-to-SPARK call until the link and an end-to-end test exist.
