#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
missing=0
run() {
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
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "MISSING: $1"; missing=$((missing + 1)); return 1; }
}

need gosec && run "gosec" bash -c 'cd bridge_service && gosec ./...'
need govulncheck && run "govulncheck" bash -c 'cd bridge_service && govulncheck ./...'
run "Go tests" bash -c 'cd bridge_service && go test ./...'

if find . -name Cargo.toml -not -path './.git/*' -print -quit | grep -q .; then
  need cargo && need cargo-audit && run "cargo-audit" cargo audit
else
  echo "SKIP: cargo-audit (no Rust project detected)"
fi

if need semgrep; then
  run "Semgrep" semgrep --config auto --error --metrics=off
else
  echo "SKIP: Semgrep (install it in the Codespace to enable local C++/Go/PowerShell SAST)"
fi

if need trivy; then
  run "Trivy" trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --ignore-unfixed .
else
  echo "SKIP: Trivy (install it in the Codespace to enable local filesystem/dependency/secret scanning)"
fi

if need osv-scanner; then
  run "OSV-Scanner" osv-scanner scan source -r .
else
  echo "SKIP: OSV-Scanner (install it in the Codespace to enable local dependency scanning)"
fi

if need shellcheck; then
  mapfile -t shell_files < <(find deploy scripts -type f \( -name '*.sh' -o -name '*.bash' \) -print)
  if ((${#shell_files[@]})); then run "ShellCheck" shellcheck "${shell_files[@]}"; fi
else
  echo "SKIP: ShellCheck"
fi

if command -v pwsh >/dev/null 2>&1; then
  if pwsh -NoProfile -Command 'Get-Module -ListAvailable PSScriptAnalyzer' | grep -q PSScriptAnalyzer; then
    run "PSScriptAnalyzer" pwsh -NoProfile -Command '$f=Get-ChildItem deploy,scripts -Recurse -Filter *.ps1 -File -ErrorAction SilentlyContinue; if($f){$r=$f|ForEach-Object{Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning};$r|Format-Table -AutoSize|Out-String|Write-Host;if($r){exit 1}}'
  else
    echo "SKIP: PSScriptAnalyzer module not installed"
  fi
else
  echo "SKIP: PowerShell/PSScriptAnalyzer"
fi

if ((failures)); then
  echo
  echo "Audit failed: $failures check(s)."
  exit 1
fi

if ((missing)); then
  echo
  echo "Audit completed with $missing optional local tool(s) missing."
  echo "GitHub Actions runs the complete toolchain in CI."
fi

echo
 echo "Local security audit completed."
