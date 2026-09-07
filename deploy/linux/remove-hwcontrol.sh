#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/hwcontrol"
SERVICE_FILE="/etc/systemd/system/hwcontrol-bridge.service"
CONFIG_DIR="${HOME}/.config/hwcontrol"
LOG_FILE="/var/log/hwcontrol.log"
DRY_RUN=0
PURGE_SECRET=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --purge-secret) PURGE_SECRET=1 ;;
    -h|--help)
      printf 'Kullanim: %s [--dry-run] [--purge-secret]\n' "$0"
      exit 0
      ;;
    *) printf 'Bilinmeyen secenek: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  printf 'Yalnizca HWControl dosyalari ve servisi kaldirilacak. Devam? [y/N] '
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

if command -v systemctl >/dev/null 2>&1; then
  run systemctl disable --now hwcontrol-bridge.service || true
fi
run rm -f "$SERVICE_FILE"
run systemctl daemon-reload || true
run rm -rf "$INSTALL_DIR"
run rm -rf "$CONFIG_DIR"
run rm -f "$LOG_FILE"

if [[ "$PURGE_SECRET" -eq 1 ]]; then
  echo 'HWCONTROL_KEY shell/profile dosyalarindan otomatik silinmez; elle eklenen satiri kontrol edin.'
fi

echo "$([[ "$DRY_RUN" -eq 1 ]] && echo 'Dry-run tamamlandi.' || echo 'HWControl kaldirildi.')"
