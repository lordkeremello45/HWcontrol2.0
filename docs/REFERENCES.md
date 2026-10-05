# HWcontrol2.0 Technical References

This page records authoritative external sources that have been used to research or design HWcontrol2.0. A reference is a design input, not proof that HWcontrol2.0 implements or has validated every technique described by that source.

## Hardware and operating-system APIs

### Windows
- Microsoft Learn — Windows Hardware/Driver documentation: https://learn.microsoft.com/windows-hardware/
- Microsoft Learn — Windows Management Instrumentation (WMI): https://learn.microsoft.com/windows/win32/wmisdk/wmi-start-page
- Microsoft Learn — Storage Reliability Counter: https://learn.microsoft.com/windows-hardware/drivers/storage/msft-storagereliabilitycounter
- Microsoft Learn — Windows services / LocalService account: https://learn.microsoft.com/windows/win32/services/localservice-account
- Microsoft Learn — Named Pipes: https://learn.microsoft.com/windows/win32/ipc/named-pipes
- Microsoft Learn — Named Pipe Security and Access Rights: https://learn.microsoft.com/windows/win32/ipc/named-pipe-security-and-access-rights
- Microsoft Learn — ReadDirectoryChangesW: https://learn.microsoft.com/windows/win32/api/winbase/nf-winbase-readdirectorychangesw
- Microsoft Learn — WinVerifyTrust: https://learn.microsoft.com/windows/win32/secauthn/winverifytrust

**HWcontrol use:** Windows service privileges, local IPC, hardware/system information, storage health, integrity monitoring and publisher-signature verification.

### Linux
- Linux kernel documentation: https://docs.kernel.org/
- Linux kernel hwmon: https://www.kernel.org/doc/html/latest/hwmon/hwmon-kernel-api.html
- Linux block I/O statistics: https://www.kernel.org/doc/html/latest/block/stat.html
- Linux fs-verity: https://www.kernel.org/doc/html/latest/filesystems/fsverity.html
- Debian: https://www.debian.org/
- Ubuntu: https://ubuntu.com/

**HWcontrol use:** sensor discovery, storage telemetry, filesystem/runtime integrity research and package distribution.

### macOS
- Apple Developer Documentation: https://developer.apple.com/documentation/
- Apple Platform Security: https://support.apple.com/guide/security/welcome/web

**HWcontrol use:** Apple Silicon platform integration, code signing, notarization and release trust.

### GPU vendors
- NVIDIA Developer / Documentation: https://developer.nvidia.com/ and https://docs.nvidia.com/
- AMD Developer: https://developer.amd.com/
- Intel Developer: https://www.intel.com/content/www/us/en/developer/overview.html

**HWcontrol use:** vendor-specific telemetry and hardware integration where an appropriate supported API exists.

## Languages, frameworks and build systems

- Flutter: https://flutter.dev/
- Dart: https://dart.dev/
- Go: https://go.dev/
- Rust: https://www.rust-lang.org/
- C++: https://isocpp.org/
- CMake: https://cmake.org/documentation/
- Ada: https://www.adacore.com/about-ada
- SPARK: https://www.adacore.com/about-spark

**HWcontrol use:** GUI, bridge, security-support boundaries, native engine, build system and security-policy components.

## Security and secure development

- NIST SP 800-218 — Secure Software Development Framework (SSDF): https://csrc.nist.gov/pubs/sp/800/218/final
- CISA Secure by Design: https://www.cisa.gov/securebydesign
- OWASP: https://owasp.org/
- MITRE CWE: https://cwe.mitre.org/
- MITRE CVE: https://www.cve.org/
- NVD: https://nvd.nist.gov/
- OpenSSF: https://openssf.org/

**HWcontrol use:** secure development, vulnerability management, threat modeling, dependency/supply-chain security and defensive design.

## Release integrity and software supply chain

- GitHub Actions: https://docs.github.com/actions
- GitHub Artifact Attestations: https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations
- GitHub Dependabot: https://docs.github.com/en/code-security/dependabot
- GitHub CodeQL: https://codeql.github.com/docs/
- Sigstore: https://www.sigstore.dev/
- Cosign: https://docs.sigstore.dev/cosign/
- SLSA: https://slsa.dev/
- SPDX: https://spdx.dev/
- CycloneDX: https://cyclonedx.org/

**HWcontrol use:** CI/CD, dependency updates, static analysis, SBOM, provenance, artifact verification and release-integrity research.

## Signing and distribution

- Microsoft MSIX documentation: https://learn.microsoft.com/windows/msix/
- Microsoft Store / Partner Center: https://learn.microsoft.com/windows/apps/publish/
- Microsoft SignTool: https://learn.microsoft.com/windows/win32/secauthenticode/signtool
- Apple Code Signing / Notarization: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- SignPath: https://signpath.org/
- SignPath documentation: https://docs.signpath.io/
- GitHub Releases: https://docs.github.com/repositories/releasing-projects-on-github
- GitHub Pages: https://docs.github.com/pages

**HWcontrol use:** Windows EXE/MSI/MSIX distribution, Microsoft Store planning, macOS Developer ID/notarization planning, SignPath evaluation and release hosting.

## Licensing

- GNU GPLv3: https://www.gnu.org/licenses/gpl-3.0.html
- GNU AGPLv3: https://www.gnu.org/licenses/agpl-3.0.html
- Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0
- SPDX License List: https://spdx.org/licenses/

**HWcontrol use:** project licensing and separation of the desktop application, website and independently licensed local security tooling.

## Project infrastructure and mirrors

- GitHub: https://github.com/
- GitLab: https://gitlab.com/
- Codeberg: https://codeberg.org/
- Stack Overflow: https://stackoverflow.com/
- Google Developers: https://developers.google.com/
- GitHub Sponsors: https://github.com/sponsors

These services are infrastructure/community references only. External visibility, community activity and independent references must never be fabricated.

## Feedback automation

- Google Forms: https://www.google.com/forms/about/
- Google Apps Script: https://developers.google.com/apps-script
- GitHub REST API: https://docs.github.com/rest

**HWcontrol use:** the Beta feedback pipeline and its GitHub Issue automation.

## Research notes

The project has also evaluated:
- authenticated localhost IPC and replay protection;
- platform-specific hardware telemetry and capability detection;
- SHA-256 checksums versus code signing and provenance;
- Windows Authenticode and macOS signing/notarization;
- GitHub Actions, SBOM and artifact attestations;
- SignPath Foundation eligibility and trusted-build integration;
- Ada/SPARK security boundaries;
- Linux package formats and portable distribution;
- Git/GitHub, GitLab and Codeberg mirroring.

These topics are documented here so future contributors can distinguish researched design inputs from verified implementation.

## Status rule

Use repository code, tests, CI evidence, packaged artifacts and real hardware/platform validation to determine whether a referenced technique is **IMPLEMENTED**, **PARTIAL**, **PLANNED**, **UNAVAILABLE**, or **VERIFIED**. Never infer implementation solely from the presence of a reference.
