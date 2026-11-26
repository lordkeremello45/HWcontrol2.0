#!/usr/bin/env bash
set -euo pipefail

APP_PATH="/Applications/HWControl"
BRIDGE_PLIST="/Library/LaunchDaemons/com.hwcontrol.bridge.plist"
GUARDIAN_PLIST="/Library/LaunchDaemons/com.hwcontrol.security-guardian.plist"
SYSTEM_SUPPORT_DIR="/Library/Application Support/HWControl"
CONFIG_DIR="${HOME}/Library/Application Support/HWControl"
LOG_FILE="/Library/Logs/HWControl/hwcontrol.log"
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
  printf 'Yalnizca HWControl uygulamasi, launch daemon servisleri ve ayarlari kaldirilacak. Devam? [y/N] '
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo 'Iptal edildi.'; exit 0; }
fi

if [[ "$EUID" -eq 0 ]]; then
  SUDO=()
else
  command -v sudo >/dev/null 2>&1 || {
    echo 'Sistem LaunchDaemon dosyalarini kaldirmak icin sudo gereklidir.' >&2
    exit 1
  }
  SUDO=(sudo)
fi

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    if [[ "${#SUDO[@]}" -gt 0 ]]; then printf ' sudo'; fi
    printf ' %q' "$@"
    printf '\n'
  else
    "${SUDO[@]}" "$@"
  fi
}

if command -v launchctl >/dev/null 2>&1; then
  run launchctl bootout system "$BRIDGE_PLIST" || true
  run launchctl bootout system "$GUARDIAN_PLIST" || true
  run launchctl disable system/com.hwcontrol.bridge || true
  run launchctl disable system/com.hwcontrol.security-guardian || true
fi

run rm -f "$BRIDGE_PLIST"
run rm -f "$GUARDIAN_PLIST"
run rm -rf "$APP_PATH"
run rm -rf "$SYSTEM_SUPPORT_DIR"
run rm -rf "$CONFIG_DIR"
run rm -f "$LOG_FILE"

echo "$([[ "$DRY_RUN" -eq 1 ]] && echo 'Dry-run tamamlandi.' || echo 'HWControl kaldirildi.')"
