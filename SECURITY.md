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
- Bridge communication is bound to `127.0.0.1` by default, so the dashboard-to-bridge telemetry path is local to the PC.
- Update checking is a separate HTTPS request to the allowlisted GitHub release infrastructure; this is not a telemetry upload channel.

This privacy model describes the intended application behavior. It does not claim that the operating system, GPU drivers, GitHub, or other third-party software on the user's machine collect no data of their own.

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

## Security audit toolchain

The repository provides a dedicated Codespaces security-audit environment and automated GitHub Actions checks.

The audit stack includes:

- `gosec` — Go security static analysis.
- `govulncheck` — Go dependency/reachable-code vulnerability analysis.
- `cargo-audit` — conditional RustSec dependency auditing when a Rust project is present.
- `Semgrep` — multi-language SAST for C++, Go, PowerShell, and other supported files.
- `Trivy` — filesystem dependency, misconfiguration, and secret scanning.
- `OSV-Scanner` — OSV dependency vulnerability scanning.
- `ShellCheck` — Linux/macOS shell installer analysis.
- `PSScriptAnalyzer` — PowerShell installer analysis.
- `CodeQL` — repository-level C++ and Go semantic security analysis.
- Gitleaks plus Trivy secret scanning — supplemental repository secret detection.
- GitHub Actions workflow permission auditing — checks for dangerous broad permissions and selected `pull_request_target` shell-execution patterns.

Run the local audit from Codespaces with:

```bash
bash scripts/security-audit-all.sh
```

The complete CI toolchain is run by `.github/workflows/security-audit-full.yml`.

### Platform boundary

Codespaces is the interactive **security/static/dependency audit** environment. It is not a substitute for platform integration testing.

GitHub Actions remains responsible for **real platform testing**:

- Windows runners validate the Windows bridge, native engine, Flutter dashboard, MSI/EXE/Setup packaging and Windows-specific installer behavior.
- macOS runners validate the macOS bridge, native engine, Flutter dashboard, PKG/DMG packaging and macOS installer behavior.
- Linux container/runner jobs validate the native engine, bridge, runtime dependencies and distribution packages across the supported x86_64 distributions.

A green Codespaces audit therefore means that the source/dependencies/security checks passed; it does not claim that Windows or macOS installer behavior was reproduced inside Linux Codespaces.

## Reporting a vulnerability

Please report security issues privately through the repository's GitHub Security tab. Do not publish credentials, private keys, or exploit details in a public issue. We will acknowledge reports and provide a remediation status when the investigation is complete.
