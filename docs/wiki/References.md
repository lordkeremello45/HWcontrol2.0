# Technical References

This document records authoritative references used to inform HWcontrol2.0 architecture, security controls, platform integration, and release engineering. References are design inputs; they do not by themselves prove that a feature is implemented or secure.

## Security & secure development

### NIST — Secure Software Development Framework (SSDF)
- **Reference:** NIST SP 800-218, SSDF v1.1
- **Use in HWcontrol:** secure development practices, vulnerability prevention, least-privilege thinking, release/security process.
- **Status:** Final publication.
- **Source:** https://csrc.nist.gov/pubs/sp/800/218/final

NIST also published an initial public draft of SSDF v1.2 in December 2025. HWcontrol should treat the final v1.1 publication as the stable baseline until a final v1.2 publication supersedes it.
- **Source:** https://csrc.nist.gov/pubs/sp/800/218/r1/ipd

### CISA — Secure by Design
- **Use in HWcontrol:** security as a product/design property, secure defaults, reducing avoidable security burden on users.
- **Source:** https://www.cisa.gov/securebydesign

## Windows security & IPC

### Microsoft — LocalService Account
- **Use in HWcontrol:** the Windows bridge service runs as `NT AUTHORITY\LocalService` rather than LocalSystem to reduce the service privilege boundary.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/services/localservice-account

### Microsoft — Named Pipe Security and Access Rights
- **Use in HWcontrol:** informs the planned stronger Windows IPC architecture using ACL-controlled named pipes and client identity.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights

### Microsoft — Named Pipes
- **Use in HWcontrol:** Windows local IPC design and security-boundary considerations.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipes

## Runtime integrity

### NIST NCCoE — Integrity Checking
- **Use in HWcontrol:** defense-in-depth runtime integrity monitoring and detection of unauthorized changes.
- **Source:** https://www.nccoe.nist.gov/publication/1800-25/VolB/index.html

### Microsoft — ReadDirectoryChangesW
- **Use in HWcontrol:** reference for a future Windows-native event-driven integrity watcher; current implementation intentionally uses cross-platform polling.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-readdirectorychangesw

## Platform security & release trust

### Apple — Code Signing / Platform Security
- **Use in HWcontrol:** future Developer ID signing, notarization, and macOS release trust chain.
- **Source:** https://support.apple.com/guide/security/welcome/web

### Linux kernel — fs-verity
- **Use in HWcontrol:** potential additional Linux runtime integrity protection where supported.
- **Source:** https://www.kernel.org/doc/html/latest/filesystems/fsverity.html

### Microsoft — Authenticode / WinVerifyTrust
- **Use in HWcontrol:** Windows release-signing and runtime publisher/signature verification design.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/secauthn/winverifytrust

## Build & supply-chain security

### GitHub — Artifact Attestations
- **Use in HWcontrol:** release provenance and build-verification strategy.
- **Source:** https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations

### GitHub — Dependabot
- **Use in HWcontrol:** dependency vulnerability alerts and controlled version updates.
- **Source:** https://docs.github.com/en/code-security/dependabot

### CMake
- **Use in HWcontrol:** native C/C++ build and platform integration.
- **Source:** https://cmake.org/documentation/

## Hardware / platform integration

### Linux kernel — hwmon
- **Use in HWcontrol:** Linux hardware-monitoring sensor architecture.
- **Source:** https://www.kernel.org/doc/html/latest/hwmon/hwmon-kernel-api.html

### Microsoft — Windows Management Instrumentation
- **Use in HWcontrol:** Windows hardware/system management integration where applicable.
- **Source:** https://learn.microsoft.com/en-us/windows/win32/wmisdk/wmi-start-page

### NVIDIA — Developer Documentation
- **Use in HWcontrol:** NVIDIA-specific hardware/telemetry integration where supported by the selected API.
- **Source:** https://docs.nvidia.com/

### AMD — Developer Documentation
- **Use in HWcontrol:** AMD-specific platform/hardware integration where supported.
- **Source:** https://developer.amd.com/

### Intel — Developer Documentation
- **Use in HWcontrol:** Intel-specific platform/hardware integration where supported.
- **Source:** https://www.intel.com/content/www/us/en/developer/overview.html

## Project-specific interpretation

These references are mapped to concrete HWcontrol engineering decisions:

| Area | HWcontrol decision |
|---|---|
| Privilege | Windows bridge uses LocalService |
| IPC | Authenticated local bridge; stronger ACL-based named-pipe design remains a future hardening path |
| Integrity | Runtime SHA-256 monitoring is defense-in-depth and fails closed |
| Hardware control | Capability-aware and safety-state-aware; unsupported controls remain unavailable |
| Native security | Compiler/linker hardening for C/C++ |
| Dependencies | Dependabot + security scanning |
| Release trust | Signing, provenance and artifact integrity are separate controls |
| Documentation | Implementation status is kept distinct from planned capabilities |

## Important limitation

A reference is not evidence that HWcontrol2.0 implements every technique described by that reference. Implementation status must be verified from the repository, tests, CI, packaged artifacts, and real hardware/platform validation.
