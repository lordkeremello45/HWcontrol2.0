# Honest Description: Current State and Limitations

HWcontrol2.0 is an open-source **Beta** project. This page records important gaps so users can make informed decisions and contributors can see what still needs evidence or implementation.

The repository's stated target is not the same thing as a feature being verified on every machine. Please check the current release notes, CI runs, and known issues before installing.

## 1. Virtual machines and test coverage

We do not currently have a published, regularly maintained VM test lab or a complete VM test matrix with reproducible results. We also do not claim exhaustive testing across operating-system versions and physical hardware configurations. This is a coverage gap, not something we should obscure.

- GitHub-hosted CI runners can test builds, code paths, packaging, and selected smoke tests, but they do not replace a full VM matrix or tests on physical hardware.
- A successful build does not prove that CPU/GPU sensors, fan control, sleep/resume, service lifecycle, or permissions work on every target system.
- Virtual machines often do not expose real fan controllers, GPU sensors, embedded-controller interfaces, or other physical hardware features. VM results alone cannot validate those functions.
- Unless a specific test run and environment are linked, do not assume that a Windows, macOS, or Linux VM test has passed.

We should publish a test matrix with OS version, architecture, runner/VM or physical hardware, tested feature, result, and date as coverage grows.

## 2. Hardware and platform compatibility

Hardware telemetry and control depend on operating-system APIs, kernel support, drivers, firmware, permissions, and the specific device.

- A sensor may be unavailable, delayed, inaccurate, or reported under a different name by a platform.
- Monitoring support does not imply control support.
- Fan control and other low-level operations must remain disabled when the relevant capability is not safely available.
- We cannot claim compatibility with every motherboard, laptop, GPU, fan controller, or storage device.
- Linux support targets Debian/Ubuntu-family x64 systems; other distributions may require additional work.
- The current macOS package target is macOS 14+ on Apple Silicon. Intel macOS is not currently a shipped target.
- Windows ARM64 packages are not currently shipped.

Before using hardware-control features, review the current release notes and keep important data backed up. Do not use a Beta tool as the sole safeguard against overheating or hardware failure.

## 3. Beta stability

The application may contain defects, incomplete platform integrations, performance issues, or UI and localization inconsistencies. Automated tests cover selected behavior, not every possible device or usage pattern.

A CI pass means only that the checks in that workflow passed for that commit and environment. It is not a general certification of product readiness.

## 4. Signing and release trust

SHA-256 checksums help determine whether a downloaded file matches the published checksum. They do not establish who created the file.

GitHub artifact attestations, where present and verified, provide provenance evidence but do not replace operating-system-trusted publisher signing.

We do not claim Windows Authenticode signing, Apple Developer ID signing, or Apple notarization for a package unless the specific release provides verifiable evidence. Operating systems may therefore display warnings or require additional steps for unsigned or unnotarized builds.

Always obtain packages from the official [GitHub Releases page](https://github.com/lordkeremello45/HWcontrol2.0/releases) and inspect the assets and release notes before installing.

## 5. Security boundaries

The design includes a local Go bridge and native hardware-facing components. Because the bridge can mediate sensitive operations, authentication, authorization, input validation, least privilege, and safe failure behavior require ongoing review.

No software can honestly be described as perfectly secure. Public source code and automated checks improve inspectability, but they do not by themselves prove the absence of vulnerabilities.

Please report security issues according to [SECURITY.md](../SECURITY.md). Avoid publishing secrets, access tokens, personal information, or unredacted diagnostic logs in public issues.

## 6. Privacy and diagnostics

Routine hardware monitoring is intended to work locally. Optional integrations and diagnostic reporting may have different data flows.

Before sharing a diagnostic archive, inspect it for usernames, file paths, device identifiers, network details, tokens, or other information you do not intend to disclose. Do not assume every log is automatically free of personal or sensitive data.

## 7. What is not promised

At this stage, we do not promise:

- universal hardware or sensor compatibility;
- fan control on every device or operating system;
- exhaustive VM and physical-hardware test coverage;
- production-grade stability for every workflow;
- OS-trusted publisher signing or notarization without release-specific evidence;
- that checksums or attestations alone establish publisher identity;
- that a successful CI run means all product-readiness criteria have passed.

## 8. How to help improve the evidence

When reporting an issue, include the application version, operating system and architecture, relevant hardware model if safe to share, the steps to reproduce, expected versus actual behavior, and relevant CI or log excerpts with sensitive values removed.

Contributors can help by adding reproducible tests, documenting tested hardware/OS combinations, validating installer and upgrade/uninstall paths, and reporting both successes and failures.

## Status statement

This is a good-faith description of current project limitations, not a substitute for the release notes or security advisories. It should be updated whenever test coverage, signing status, supported platforms, or known limitations materially change.
