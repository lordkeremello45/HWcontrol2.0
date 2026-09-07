#!/usr/bin/env bash
set -euo pipefail
REPO='lordkeremello45/HWcontrol2.0'
API="https://api.github.com/repos/$REPO/releases"
TMP_DIR="${TMPDIR:-/tmp}/hwcontrol-installer"
INSTALL_DIR="/opt/hwcontrol"
mkdir -p "$TMP_DIR"
printf '\nHWControl Linux Installer\nDetecting Linux distribution and latest stable compatible package...\n'
if [ "$(id -u)" -eq 0 ]; then SUDO=''; else SUDO='sudo'; fi
ID=''; ID_LIKE=''; [ -r /etc/os-release ] && . /etc/os-release
ID="${ID:-}"; ID_LIKE="${ID_LIKE:-}"
family='generic'
case " $ID $ID_LIKE " in
  *' debian '*|*' ubuntu '*|*' linuxmint '*|*' pop '*|*' elementary '*|*' zorin '*) family='debian' ;;
  *' fedora '*|*' rhel '*|*' centos '*|*' rocky '*|*' almalinux '*|*' nobara '*) family='rpm' ;;
  *' arch '*|*' manjaro '*|*' endeavouros '*|*' garuda '*) family='arch' ;;
esac
echo "Distribution family: $family"
release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: HWControl-Installer' "$API")"
release_json="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(json.dumps(next(x for x in r if x["tag_name"].endswith("-linux") and not x["draft"] and not x["prerelease"])))')"
tag="$(printf '%s' "$release_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
asset_url(){ printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); s=sys.argv[1]; print(next((a["browser_download_url"] for a in r["assets"] if a["name"].endswith(s)), ""))' "$1"; }
asset_name(){ printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); s=sys.argv[1]; print(next((a["name"] for a in r["assets"] if a["name"].endswith(s)), ""))' "$1"; }
sha_url="$(asset_url '.sha256')"; deb_url="$(asset_url '.deb')"; rpm_url="$(asset_url '.rpm')"; arch_url="$(asset_url '.pkg.tar.zst')"; zst_url="$(asset_url '.tar.zst')"; gz_url="$(asset_url '.tar.gz')"
[ -n "$sha_url" ] || { echo "The latest Linux release ($tag) has no SHA-256 manifest. Installation is blocked." >&2; exit 1; }
sha_name="$(asset_name '.sha256')"; [ -n "$sha_name" ] || exit 1
sha_file="$TMP_DIR/$sha_name"; curl -fL -o "$sha_file" "$sha_url"
verify_sha(){ local file="$1" base expected actual; base="$(basename "$file")"; expected="$(awk -v f="$base" '$2 == f || $2 == "*" f {print $1; exit}' "$sha_file")"; [ -n "$expected" ] || { echo "No SHA-256 entry for $base was found." >&2; exit 1; }; actual="$(sha256sum "$file"|awk '{print $1}')"; [ "$actual" = "$expected" ] || { echo "SHA-256 verification failed for $base." >&2; exit 1; }; echo "SHA-256 verification: OK ($base)"; }
install_deb(){ local file="$1"; verify_sha "$file"; $SUDO apt-get install -y "$file"; }
install_rpm(){ local file="$1"; verify_sha "$file"; if command -v dnf >/dev/null; then $SUDO dnf install -y "$file"; elif command -v yum >/dev/null; then $SUDO yum install -y "$file"; else echo 'dnf/yum is required for RPM installation.' >&2; exit 1; fi; }
install_arch(){ local file="$1"; verify_sha "$file"; command -v pacman >/dev/null || { echo 'pacman is required for Arch package installation.' >&2; exit 1; }; $SUDO pacman -U --noconfirm "$file"; }
install_archive(){ local file="$1" format="$2" stage="$TMP_DIR/stage" source_dir dashboard_bin; rm -rf "$stage"; mkdir -p "$stage"; verify_sha "$file"; case "$format" in zst) command -v zstd >/dev/null || { echo 'zstd is required.' >&2; exit 1; }; tar --use-compress-program=zstd -xf "$file" -C "$stage";; gz) tar -xzf "$file" -C "$stage";; *) exit 1;; esac; source_dir="$(find "$stage" -mindepth 1 -maxdepth 1 -type d | head -n1)"; [ -n "$source_dir" ] || { echo 'Invalid HWControl archive layout.' >&2; exit 1; }; $SUDO rm -rf "$INSTALL_DIR"; $SUDO mkdir -p "$INSTALL_DIR"; $SUDO cp -a "$source_dir/." "$INSTALL_DIR/"; $SUDO chmod 0755 "$INSTALL_DIR/bridge-service" "$INSTALL_DIR/ai_engine" 2>/dev/null || true; if [ -f "$INSTALL_DIR/deploy/hwcontrol-bridge.service" ]; then $SUDO install -m0644 "$INSTALL_DIR/deploy/hwcontrol-bridge.service" /etc/systemd/system/hwcontrol-bridge.service; $SUDO systemctl daemon-reload; $SUDO systemctl enable hwcontrol-bridge.service >/dev/null; fi; if [ -d "$INSTALL_DIR/dashboard" ]; then dashboard_bin="$(find "$INSTALL_DIR/dashboard" -type f -name hwcontrol_dashboard -executable | head -n1)"; [ -n "$dashboard_bin" ] && $SUDO ln -sf "$dashboard_bin" /usr/local/bin/hwcontrol; fi; }
case "$family" in
 debian) if [ -n "$deb_url" ]; then f="$TMP_DIR/$(asset_name '.deb')"; curl -fL -o "$f" "$deb_url"; install_deb "$f"; echo "HWControl $tag installed via .deb."; exit 0; fi;;
 rpm) if [ -n "$rpm_url" ]; then f="$TMP_DIR/$(asset_name '.rpm')"; curl -fL -o "$f" "$rpm_url"; install_rpm "$f"; echo "HWControl $tag installed via RPM."; exit 0; fi;;
 arch) if [ -n "$arch_url" ]; then f="$TMP_DIR/$(asset_name '.pkg.tar.zst')"; curl -fL -o "$f" "$arch_url"; install_arch "$f"; echo "HWControl $tag installed via Arch package."; exit 0; fi;;
esac
if [ -n "$zst_url" ]; then f="$TMP_DIR/$(asset_name '.tar.zst')"; curl -fL -o "$f" "$zst_url"; install_archive "$f" zst; echo "HWControl $tag installed via .tar.zst."; exit 0; fi
if [ -n "$gz_url" ]; then f="$TMP_DIR/$(asset_name '.tar.gz')"; curl -fL -o "$f" "$gz_url"; install_archive "$f" gz; echo "HWControl $tag installed via .tar.gz."; exit 0; fi
echo 'No usable Linux package was found for this system.' >&2; exit 1
