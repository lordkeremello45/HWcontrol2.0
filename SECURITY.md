# Security Policy

## Supported Versions

Security fixes are provided for the latest stable release and the `main` branch.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub's private vulnerability reporting mechanism when available. Do not publish credentials, private keys, bridge secrets, or exploit details in a public issue.

## Security Architecture

HWControl uses a local-first architecture. The bridge service listens only on `127.0.0.1`, authenticates dashboard requests with HMAC-SHA256, validates command values, and keeps the bridge secret in an OS-protected application-data location rather than requiring a public network endpoint.

The project also includes BSOD Shield protections and release-integrity controls. Release artifacts are covered by SHA-256, SHA-512, and SHA3-512 manifests plus GitHub Actions provenance/attestation where supported.

## Security Audit Toolchain

The repository provides a dedicated Codespaces security-audit environment and automated GitHub Actions checks.

The audit stack includes:

- `gosec` — Go security static analysis.
- `govulncheck` — Go vulnerability analysis for dependencies and reachable vulnerable code.
- `cargo-audit` — conditional RustSec dependency auditing when a Rust project is present.
- `Semgrep` — multi-language SAST for C++, Go, PowerShell, and other supported source files.
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

## Release and Update Security

Only official GitHub Releases are trusted as release sources. Update endpoints must use HTTPS and the repository allowlist. Updates are not silently executed; integrity validation is required before installation.

Artifact integrity and Windows publisher identity are separate properties. Unsigned Windows artifacts may still trigger SmartScreen because publisher identity is not established by SHA checksums or GitHub Actions provenance alone.
