#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Go security tools are installed into the Codespaces user environment.
go install github.com/securego/gosec/v2/cmd/gosec@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

echo "Security audit tools installed. Run: bash scripts/security-audit.sh"
