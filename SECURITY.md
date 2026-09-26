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
- Unix deployments use a permission-protected socket by default; Windows uses authenticated loopback TCP.
- The bridge does not grant hardware-control authority to the local AI process.

This is an application-layer defense. Local administrator/root compromise, a compromised desktop user account, or a compromised OS/driver can bypass application-level trust boundaries.

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
