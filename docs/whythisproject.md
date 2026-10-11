# Why HWcontrol2.0?

HWcontrol2.0 is an open-source project exploring how hardware monitoring, supported device control, diagnostics, and release transparency can fit into one desktop application without hiding the implementation from users.

This page explains the project's motivation and intended strengths. It is not a claim that every feature is complete, every device is supported, or that HWcontrol2.0 is better than every alternative.

## The problem we want to solve

Hardware information and control utilities can be fragmented across operating systems, device vendors, drivers, and separate tools. Users may need one tool for monitoring, another for fan control, and another to diagnose application or bridge failures.

HWcontrol2.0 aims to bring these workflows together while making capability limits and safety boundaries visible.

## What we aim to do differently

### 1. One application, an explicit multi-layer architecture

The project uses a Flutter/Dart dashboard, an authenticated localhost Go bridge, and a native C++/CMake engine that integrates with platform-specific hardware APIs.

This separation is intended to make the UI, command boundary, and low-level hardware integration easier to inspect and test independently. The architecture is a design choice, not proof that every layer is already fully hardened.

### 2. Capability-gated hardware control

Monitoring a device does not automatically mean it is safe or possible to control it. Hardware access varies with the operating system, kernel, drivers, firmware, permissions, and device model.

HWcontrol2.0 aims to expose control only when a backend declares the relevant capability. Unsupported paths should remain monitor-only rather than presenting a control that cannot work safely.

### 3. Monitoring and diagnostics in the same workflow

The intended product combines available CPU, GPU, storage, memory, and fan telemetry with temperature history, alerts, bridge diagnostics, health states, and diagnostic exports. Exact metrics depend on what a platform reliably exposes.

This reduces the need to switch between unrelated tools when investigating a problem, provided the relevant platform integration is implemented.

### 4. Local-first operation

The core application is designed around local hardware access and a local bridge rather than requiring a cloud account for routine monitoring. Optional integrations should remain separable from the core runtime.

Local-first does not mean that every optional feature is automatically private or that logs can never contain sensitive information. Users should review diagnostic exports before sharing them.

### 5. Release integrity is part of the product

The project works toward repeatable builds, platform-specific packages, SHA-256 checksums, automated validation, and artifact provenance where configured. These mechanisms make releases easier to inspect and verify.

Checksums establish file integrity, not publisher identity. Artifact attestations are not the same as OS-trusted code signing. We will only claim Authenticode signing, Apple Developer ID signing, or notarization when the release is actually signed and verification evidence is available.

### 6. Open source and visible limitations

The source code, issue tracker, documentation, and CI workflows give users and contributors a way to inspect implementation choices and report problems. The project is in Beta, so bugs, missing integrations, and incomplete test coverage remain possible.

We prefer a documented limitation over a promise that cannot yet be supported by evidence.

## Current scope

The current intended release targets are:

- Windows 10/11 x64
- macOS 14+ on Apple Silicon
- Debian/Ubuntu-family Linux x64

These are release targets, not a guarantee that every feature works on every supported operating system or hardware model. Windows ARM64 and Intel macOS packages are not currently shipped.

## How to evaluate us fairly

We encourage users to judge HWcontrol2.0 by observable evidence:

- Does the feature work on their actual device and operating system?
- Are unsupported hardware-control paths handled safely?
- Are failures reproducible and documented?
- Do CI results and release assets match the claims?
- Can users inspect the code and understand the privacy and security boundaries?

See [Honest Description](honestdescription.md) for current gaps and limitations, the [Beta Quickstart](USER-QUICKSTART.md) for cautious installation, and the [Product Readiness Checklist](PRODUCT-READINESS-CHECKLIST.md) for acceptance criteria.

## In short

Our goal is not to claim that HWcontrol2.0 has already solved every hardware-monitoring problem. Our goal is to build a transparent, cross-platform, local-first tool that combines monitoring, capability-aware control, diagnostics, and release integrity—and to show progress through code, tests, and verifiable releases.
