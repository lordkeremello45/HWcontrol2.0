#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"

failures=0
run_check() {
  local name="$1"; shift
  echo
  echo "==> $name"
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

command -v gosec >/dev/null 2>&1 || { echo "gosec is missing; run .devcontainer/setup-security.sh"; exit 2; }
command -v govulncheck >/dev/null 2>&1 || { echo "govulncheck is missing; run .devcontainer/setup-security.sh"; exit 2; }

run_check "Go vulnerability scan" bash -c 'cd bridge_service && govulncheck ./...'
run_check "Go static security scan" bash -c 'cd bridge_service && gosec ./...'
run_check "Go tests" bash -c 'cd bridge_service && go test ./...'

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t shell_files < <(find deploy scripts -type f \( -name "*.sh" -o -name "*.bash" \) -print 2>/dev/null)
  if ((${#shell_files[@]})); then
    run_check "Shell script lint" shellcheck "${shell_files[@]}"
  fi
else
  echo "INFO: shellcheck not installed; skipping shell lint"
fi

if command -v node >/dev/null 2>&1 && [[ -f website/app.js ]]; then
  run_check "Website JavaScript syntax" node --check website/app.js
fi

if [[ -f website/release.json ]]; then
  run_check "Release metadata JSON" node -e 'JSON.parse(require("fs").readFileSync("website/release.json", "utf8"))'
fi

if ((failures)); then
  echo
  echo "Security audit completed with $failures failing check(s)."
  exit 1
fi

echo
 echo "Security audit completed successfully."
