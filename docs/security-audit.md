# Security Audit Matrix

| Tool | Scope | Environment |
|---|---|---|
| gosec | Go security static analysis | Codespaces + CI |
| govulncheck | Go dependency/reachable vulnerability analysis | Codespaces + CI |
| cargo-audit | RustSec dependency audit, conditional | Codespaces + CI |
| Semgrep | C++/Go/PowerShell and supported-language SAST | CI; local when installed |
| Trivy | Filesystem dependencies, misconfigurations, secrets | CI; local when installed |
| OSV-Scanner | OSV dependency vulnerability scan | CI; local when installed |
| ShellCheck | Linux/macOS shell installers | Codespaces + CI |
| PSScriptAnalyzer | PowerShell installers | Codespaces when `pwsh` exists + CI |
| CodeQL | Repository-level semantic analysis | CI |
| Gitleaks | Git secret leak detection | CI |
| GitHub secret scanning | Native GitHub secret detection | Repository Security settings |
| Workflow permission audit | GitHub Actions permissions and selected unsafe trigger patterns | CI |

## Boundary

Codespaces is deliberately treated as the interactive security/static/dependency lab. It does not attempt to emulate Windows or macOS installers.

GitHub Actions remains the platform-validation layer for Windows MSI/EXE/Setup behavior, macOS PKG/DMG behavior, and Linux distribution/runtime behavior.

The native GitHub secret-scanning feature is account/repository security configuration rather than a workflow executable. Gitleaks and Trivy are included as repository-level supplemental scanners so secret detection also runs as part of CI.
