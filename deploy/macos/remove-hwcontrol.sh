#!/usr/bin/env bash
set -euo pipefail

APP_PATH="/Applications/HWControl.app"
SERVICE_PATH="${HOME}/Library/LaunchAgents/com.hwcontrol.bridge.plist"
CONFIG_DIR="${HOME}/Library/Application Support/HWControl"
LOG_FILE="${HOME}/Library/Logs/HWControl/hwcontrol.log"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      printf 'Kullanim: %s [--dry-run]\n' "$0"
      exit 0
      ;;
    *) printf 'Bilinmeyen secenek: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  printf 'Yalnizca HWControl uygulamasi, servisi ve ayarlari kaldirilacak. Devam? [y/N] '
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo 'Iptal edildi.'; exit 0; }
fi

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+ %q' "$1"; shift; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

if command -v launchctl >/dev/null 2>&1; then
  run launchctl bootout "gui/$(id -u)/com.hwcontrol.bridge" || true
fi
run rm -f "$SERVICE_PATH"
run rm -rf "$APP_PATH"
run rm -rf "$CONFIG_DIR"
run rm -f "$LOG_FILE"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo 'Dry-run tamamlandi.'
else
  echo 'HWControl kaldirildi.'
fi
