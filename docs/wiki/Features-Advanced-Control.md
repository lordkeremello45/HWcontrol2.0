# Advanced Control and Automation

## Smart Fan Curve

HWcontrol2.0 now stores a point-based fan curve locally and interpolates the requested fan target from CPU temperature.

Safety rules:

- fan targets are clamped to 0–100%;
- temperature points are clamped to a safe configuration domain;
- automatic commands are blocked when telemetry is invalid or critical temperature is detected;
- automatic control remains disabled unless the bridge reports a validated writable hardware-control backend;
- monitor-only hardware is never treated as controllable.

The editor is therefore usable on every platform, while actual fan actuation remains capability-driven.

## Hardware Automation

Automation rules can react to CPU/GPU temperature thresholds and select a fan target. Rules are local configuration and are evaluated only against fresh bridge telemetry.

The rule engine does not execute arbitrary scripts or load arbitrary plugins.

## Benchmark

The dashboard includes a bounded one-second CPU microbenchmark. It is an observation tool, not a stress test, and does not modify clocks, voltage, power limits or fan settings.

## Extension API

The first extension boundary is a metadata/capability manifest contract. Arbitrary native code is intentionally not loaded from user-writable directories.

A future executable extension host must add signature verification and an explicit capability grant before any privileged operation is exposed.
