# HWControl 2.0

Cross-platform hardware monitoring and control application with a Flutter dashboard, native C++ AI/core engine, and Go bridge service.

## Security auditing

The repository includes a dedicated Codespaces environment for security/static/dependency analysis.

Run the full local audit with:

```bash
bash scripts/security-audit-all.sh
```

The automated security workflow covers Go security analysis, Semgrep, Trivy, OSV-Scanner, ShellCheck, PSScriptAnalyzer, conditional cargo-audit, CodeQL, secret scanning, and GitHub Actions permission auditing.

**Important:** Codespaces is not a Windows/macOS installer emulator. Platform/package behavior remains validated by the existing GitHub Actions Windows, macOS, and Linux jobs.

See `SECURITY.md` for the security model, release-integrity guidance, and the Codespaces/Actions testing boundary.
