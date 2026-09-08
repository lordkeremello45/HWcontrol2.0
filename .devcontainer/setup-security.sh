#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Go security tools.
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

# ShellCheck is useful for Linux/macOS installer scripts.
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y shellcheck
fi

# Semgrep provides cross-language SAST for C++/Go/PowerShell and other supported files.
if command -v pipx >/dev/null 2>&1; then
  pipx install semgrep || pipx upgrade semgrep
elif command -v python3 >/dev/null 2>&1; then
  python3 -m pip install --user semgrep
fi

# Rust is conditional: this repository currently has no Rust project.
if find . -name Cargo.toml -not -path './.git/*' -print -quit | grep -q .; then
  if command -v cargo >/dev/null 2>&1; then
    cargo install cargo-audit --locked
  fi
fi

# PowerShell is conditional because Linux Codespaces may not include pwsh by default.
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command 'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber'
fi

echo
 echo "Codespaces security tooling is ready."
echo "Run: bash scripts/security-audit-all.sh"
echo "CI additionally runs Trivy, OSV-Scanner, CodeQL, and repository secret scanning."
