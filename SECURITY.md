# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.2.x   | :white_check_mark: |
| 0.1.x   | :x: |
| < 0.1   | :x: |

Security fixes and release-integrity improvements are applied to the currently supported release line.

## Telemetry and privacy

HWControl follows a **local-first telemetry model**.

- Hardware and system metrics are collected on the user's PC by the local bridge service and consumed locally by the dashboard.
- The application does **not intentionally collect or transmit unnecessary telemetry, usage analytics, advertising identifiers, or behavioral tracking data**.
- Routine monitoring data such as CPU/GPU utilization, temperatures, memory, disk usage, fan state, driver information, uptime, and related hardware diagnostics remains on the local machine unless the user explicitly exports or shares it.
- On Linux and macOS, dashboard-to-bridge communication uses a permission-protected Unix domain socket by default. Windows currently uses authenticated loopback TCP at `127.0.0.1` until the native named-pipe client path is completed.
- Update checking is a separate HTTPS request to the allowlisted GitHub release infrastructure; this is not a telemetry upload channel.

This privacy model describes the intended application behavior. It does not claim that the operating system, GPU drivers, GitHub, or other third-party software on the user's machine collect no data of their own.

## Bridge authentication and replay protection

The local bridge requires an HMAC-SHA-256 authentication tag for every IPC request. The authenticated payload includes the action, value, a client-generated timestamp, and a cryptographically random nonce.

- Commands outside a 30-second timestamp window are rejected.
- Nonces are accepted only once during their validity window, preventing rapid replay of an observed authenticated command.
- The replay cache is bounded and expired entries are removed to prevent memory growth from unique authenticated requests.
- Authenticated commands are rate-limited per connection to reduce command-flooding pressure on hardware telemetry/control paths.
- Authentication failures are limited per connection and the connection is closed after repeated failures.
- Request bodies are size-bounded and connections have read/write deadlines.
- Unix deployments use a permission-protected `0660` socket owned by the service account and the installer-selected desktop group; Windows uses authenticated loopback TCP.
- The optional local AI process receives telemetry through its stdio interface and is not given bridge authentication credentials in its process environment.
- The AI process is not treated as an OS-level security boundary: a same-user compromised process may still access files readable by that user.

This is an application-layer defense. Local administrator/root compromise, a compromised desktop user account, or a compromised OS/driver can bypass application-level trust boundaries.

## Tamper detection and runtime integrity monitoring

HWControl uses a defense-in-depth **Tamper Detection & Integrity Monitoring** layer for security-sensitive runtime state.

At bridge startup, the monitor establishes a cryptographic baseline for:

- the file-backed `bridge.key`;
- the running bridge executable;
- the packaged native `ai_engine` executable when present;
- additional explicitly installed critical executables/libraries supplied through `HWCONTROL_INTEGRITY_FILES`.

Every monitored target must remain a regular, non-symlink file. The monitor continuously recomputes SHA-256 digests while the bridge is running.

A detected missing, replacement, symlink substitution, or content modification causes:

1. an integrity security event to be logged;
2. the global integrity state to become unhealthy;
3. new authenticated IPC requests to be rejected;
4. the bridge listener to be stopped;
5. hardware-control access to remain fail-closed;
6. trusted repair/reinstallation to be required.

The monitor does **not** automatically restore or regenerate a changed critical file or credential. A self-healing mechanism based on an untrusted local file could preserve an attacker-controlled replacement.

The runtime hash baseline is a detection control, not a cryptographic root of trust: an attacker who can replace both the executable and its trusted baseline can defeat a local hash-only scheme. For release builds, the stronger trust chain is platform code signing plus release provenance/checksums. Windows uses Authenticode when signing is available; macOS distribution is intended to use Developer ID signing and notarization; Linux packages use release checksums/provenance, with filesystem-level integrity mechanisms such as fs-verity applicable where the deployment supports them.

On Windows, Authenticode verification is provided by the Windows trust provider; on macOS, the operating system can validate signed code and its sealed components. These platform trust mechanisms are preferred over treating a mutable local hash file as the root of trust.

When `HWCONTROL_KEY` is explicitly supplied through the environment, file-backed key monitoring is disabled because there is no authoritative credential file to monitor. Runtime executable/library monitoring remains available through the explicit integrity target configuration.

This layer is defense-in-depth. It does not prevent a local administrator/root compromise, a compromised kernel/driver, or modification of the running process's memory, and it does not replace OS-enforced IPC authorization.

## Security decision boundary

The security path is deliberately split by responsibility:

```
Flutter / Dart
      |
      v
Go Bridge
  |   |-- HMAC-SHA-256 authentication
  |   |-- timestamp / nonce / replay protection
  |   |-- runtime integrity monitor
  v
SPARK Security Core
  |   |-- authorization
  |   |-- input and telemetry validation
  |   |-- safety invariants
  |   |-- fail-closed ALLOW / DENY decision
  v
Rust Security Support
  |   |-- bounded FFI/ABI representation
  |   |-- safe decision transport
  |   |-- unknown decision => DENY
  v
C++ Hardware Engine
  |
  v
OS / vendor API / hardware
```

SPARK is the policy authority. Rust is an integration boundary and must never upgrade a SPARK denial to an allow or perform hardware I/O. The Rust support crate is intentionally dependency-free. Its native link to the SPARK C ABI is kept behind an explicit feature until the supported GNAT/SPARK toolchain is validated on each target platform.

### Bridge key lifecycle

The bridge key is generated locally with the operating system cryptographic random source when no valid key exists. Installers do not ship a shared project-wide bridge key and do not download one from the internet. The key is unique to the local installation, stored in the service's protected data directory, created with exclusive file creation, and validated as a 32-byte hexadecimal secret. On POSIX systems it is restricted to owner read/write permissions; Windows installation checks additionally verify that ordinary Users do not receive unsafe write/modify access to the protected application-data directory.

The file-backed key remains the canonical daemon credential because HWControl's bridge runs as a service account on Windows/Linux/macOS, while the dashboard may run as the interactive user. Moving the same credential into a per-user desktop keychain would create an incompatible trust boundary for the service. OS-native keychains remain appropriate for future user-scoped credentials, but are not used as a forced replacement for the service bridge key.

### Release integrity and provenance

Release checksum manifests are now included as subjects of the GitHub Actions artifact-attestation step alongside the packages they describe. GitHub documents artifact attestations as signed provenance claims and explicitly supports signing manifests containing hashes. Consumers can verify the attestation and the SHA-256 manifest independently. This does not replace platform code signing.

## Hardware-control safety gate

Hardware control requests are fail-closed at the bridge boundary.

- Fan-control commands are rejected when the backend reports monitor-only or unsupported control.
- Critical CPU/GPU temperatures at or above 95 °C block fan-control commands.
- Missing/invalid thermal telemetry also blocks fan-control commands; the control path never treats an unknown temperature as safe.
- Command values are range-validated before execution.
- The safety gate is evaluated in the bridge process rather than trusting GUI state.

The 95 °C threshold is an application-level defensive threshold, not a replacement for firmware, driver, motherboard, GPU, or operating-system thermal protections.

## Runtime safety — BSOD Shield

HWControl includes a **BSOD Shield** safety layer in the AI/core runtime. The shield monitors the core execution loop and can stop processing when its health/heartbeat checks indicate that the runtime is no longer healthy. This is a **risk-reduction mechanism**, not a guarantee that Windows can never crash.

The BSOD Shield is intended to add a defensive layer around hardware-monitoring and AI/core operations. It should not be interpreted as replacing Windows, driver, firmware, or hardware safeguards.

Source implementation:

```text
ai_core/include/bsod_shield.h
ai_core/src/bsod_shield.cpp
```

## Local security tooling

The repository includes an offline Apache-2.0 security utility at `security/local-audit/`. It can verify SHA-256 digests of security-sensitive local files, reject symlink substitutions, reject non-regular targets, and reject manifest paths that escape the selected audit root. It is intentionally independent of the desktop runtime and can be used locally or from CI.

Example:

```sh
go test ./security/local-audit
go run ./security/local-audit --root . --manifest ./security/local-audit/manifest.example.json
```

The tool is a defense-in-depth integrity check. It does not replace platform code signing, release provenance, or an independently trusted manifest.

## Release integrity

Release packages are published only from the official GitHub repository. Platform packages have matching `.sha256` checksum assets. Verify a download before running it.

Linux:

```sh
sha256sum -c HWControl-vX.Y.Z-linux-Linux-x64.sha256
```

Windows:

```powershell
Get-FileHash .\HWControl-vX.Y.Z-windows-Windows-x64.zip -Algorithm SHA256
```

For a local Windows package, the repository also includes an offline verifier:

```powershell
.\installer\verify-windows-release.ps1 `
  -Artifact .\HWControl-vX.Y.Z-windows-Windows-x64.msi `
  -ChecksumFile .\HWControl-vX.Y.Z-windows-Windows-x64.sha256
```

The verifier fails closed if the package is missing, the checksum entry is missing, or the calculated SHA-256 does not match the published value.

### Build provenance

Release workflows use GitHub Actions provenance/attestation for supported release artifacts. Provenance helps establish where and how an artifact was built; SHA-256 establishes that the downloaded artifact matches the published checksum. Neither mechanism establishes Windows publisher identity.

The intended trust chain is:

```text
Official GitHub Release
        |
        +--> SHA-256 checksum
        |
        +--> GitHub Actions build provenance
        |
        +--> Local verification
        |
        +--> HWControl package
```

## Why Windows may still show SmartScreen

HWControl releases may be distributed unsigned while the project is open source. An unsigned Windows EXE/MSI can therefore display **Unknown publisher** or **Windows protected your PC** / SmartScreen warnings even when its SHA-256 checksum and build provenance are valid.

These warnings cannot be legitimately removed by changing the installer, renaming files, or attempting to bypass SmartScreen. Establishing a Windows publisher identity requires Authenticode code signing with a certificate.

Until code signing is enabled, users should obtain packages only from the official repository release and verify the published SHA-256 checksum before execution. The release workflow is prepared to enable Authenticode signing later through protected GitHub Actions secrets without changing the package layout.

## Update security

The dashboard does not install or execute updates automatically. It accepts only HTTPS links to the allowlisted GitHub repository and requires a release checksum asset before showing an update.

## Reporting a vulnerability

Please report security issues privately through the repository's GitHub Security tab. Do not publish credentials, private keys, or exploit details in a public issue. We will acknowledge reports and provide a remediation status when the investigation is complete.
