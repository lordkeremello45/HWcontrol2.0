#!/usr/bin/env bash
set -euo pipefail

REPO='lordkeremello45/HWcontrol2.0'
API="https://api.github.com/repos/$REPO/releases"
TMP_DIR="${TMPDIR:-/tmp}/hwcontrol-installer"
INSTALL_DIR="/opt/hwcontrol"

mkdir -p "$TMP_DIR"

printf '\nHWControl Linux Installer\n'
printf '%s\n' 'Detecting Linux distribution and latest compatible package...'

if [ "$(id -u)" -eq 0 ]; then
  SUDO=''
else
  SUDO='sudo'
fi

# Detect distro family without requiring lsb_release.
ID=''
ID_LIKE=''
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  ID="${ID:-}"
  ID_LIKE="${ID_LIKE:-}"
fi

family='generic'
case " $ID $ID_LIKE " in
  *' debian '*|*' ubuntu '*|*' linuxmint '*|*' pop '*|*' elementary '*|*' zorin '*) family='debian' ;;
  *' fedora '*|*' rhel '*|*' centos '*|*' rocky '*|*' almalinux '*|*' nobara '*) family='rpm' ;;
  *' arch '*|*' manjaro '*|*' endeavouros '*|*' garuda '*) family='arch' ;;
esac

case "$family" in
  debian) echo "Distribution family: Debian/Ubuntu" ;;
  rpm) echo "Distribution family: Fedora/RHEL" ;;
  arch) echo "Distribution family: Arch" ;;
  *) echo "Distribution family: generic Linux" ;;
esac

release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: HWControl-Installer' "$API")"
release_json="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(json.dumps(next(x for x in r if x["tag_name"].endswith("-linux") and not x["draft"])))')"
tag="$(printf '%s' "$release_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
asset_url() {
  local suffix="$1"
  printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); s=sys.argv[1]; print(next((a["browser_download_url"] for a in r["assets"] if a["name"].endswith(s)), ""))' "$suffix"
}

sha_url="$(asset_url '.sha256')"
deb_url="$(asset_url '.deb')"
zst_url="$(asset_url '.tar.zst')"
gz_url="$(asset_url '.tar.gz')"

if [ -z "$deb_url" ] && [ -z "$zst_url" ] && [ -z "$gz_url" ]; then
  echo "No supported Linux package (.deb, .tar.zst, or .tar.gz) is available in $tag." >&2
  exit 1
fi

sha_file="$TMP_DIR/HWControl-$tag.sha256"
if [ -n "$sha_url" ]; then
  curl -fL -o "$sha_file" "$sha_url"
fi

verify_sha() {
  local file="$1"
  local basename_file
  basename_file="$(basename "$file")"
  if [ -s "$sha_file" ]; then
    local expected actual
    expected="$(awk -v f="$basename_file" '$0 ~ f {print $1; exit}' "$sha_file")"
    if [ -n "$expected" ]; then
      actual="$(sha256sum "$file" | awk '{print $1}')"
      [ "$actual" = "$expected" ] || { echo "SHA-256 verification failed for $basename_file. Nothing was installed." >&2; exit 1; }
      echo "SHA-256 verification: OK"
    fi
  fi
}

install_deb() {
  local file="$1"
  echo "Installing native Debian package: $(basename "$file")"
  verify_sha "$file"
  $SUDO apt-get install -y "$file"
}

install_archive() {
  local file="$1"
  local format="$2"
  local stage="$TMP_DIR/stage"
  rm -rf "$stage"
  mkdir -p "$stage"
  verify_sha "$file"

  case "$format" in
    zst)
      command -v zstd >/dev/null 2>&1 || {
        echo 'zstd is required for the .tar.zst package but is not installed.' >&2
        echo 'Install zstd with your distro package manager and run this installer again.' >&2
        exit 1
      }
      tar --use-compress-program=zstd -xf "$file" -C "$stage"
      ;;
    gz)
      tar -xzf "$file" -C "$stage"
      ;;
  esac

  source_dir="$(find "$stage" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$source_dir" ] || { echo 'Invalid HWControl archive: package directory not found.' >&2; exit 1; }

  echo "Installing portable Linux bundle to $INSTALL_DIR"
  $SUDO rm -rf "$INSTALL_DIR"
  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO cp -a "$source_dir/." "$INSTALL_DIR/"
  $SUDO chmod 0755 "$INSTALL_DIR/bridge-service" "$INSTALL_DIR/ai_engine" 2>/dev/null || true

  if [ -f "$INSTALL_DIR/deploy/hwcontrol-bridge.service" ]; then
    $SUDO install -m 0644 "$INSTALL_DIR/deploy/hwcontrol-bridge.service" /etc/systemd/system/hwcontrol-bridge.service
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable hwcontrol-bridge.service >/dev/null
    echo 'HWControl bridge service registered with systemd.'
  fi

  if [ -d "$INSTALL_DIR/dashboard" ]; then
    dashboard_bin="$(find "$INSTALL_DIR/dashboard" -maxdepth 2 -type f -executable -name 'hwcontrol_dashboard' -o -name 'hwcontrol_dashboard' | head -n 1)"
    if [ -n "$dashboard_bin" ]; then
      $SUDO ln -sf "$dashboard_bin" /usr/local/bin/hwcontrol
      echo 'Command installed: hwcontrol'
    fi
  fi
}

# Prefer the native package when it matches the detected distro family.
case "$family" in
  debian)
    if [ -n "$deb_url" ]; then
      file="$TMP_DIR/HWControl-$tag.deb"
      curl -fL -o "$file" "$deb_url"
      install_deb "$file"
      echo "HWControl $tag installed successfully via .deb."
      exit 0
    fi
    ;;
esac

# Arch, Fedora/RHEL, and generic Linux use the compressed portable bundle.
if [ -n "$zst_url" ]; then
  file="$TMP_DIR/HWControl-$tag.tar.zst"
  curl -fL -o "$file" "$zst_url"
  install_archive "$file" zst
  echo "HWControl $tag installed successfully via .tar.zst."
  exit 0
fi

if [ -n "$gz_url" ]; then
  file="$TMP_DIR/HWControl-$tag.tar.gz"
  curl -fL -o "$file" "$gz_url"
  install_archive "$file" gz
  echo "HWControl $tag installed successfully via .tar.gz."
  exit 0
fi

# Last-resort Debian fallback for a non-Debian host only when no archive exists.
if [ -n "$deb_url" ] && command -v apt-get >/dev/null 2>&1; then
  file="$TMP_DIR/HWControl-$tag.deb"
  curl -fL -o "$file" "$deb_url"
  install_deb "$file"
  echo "HWControl $tag installed successfully via .deb fallback."
  exit 0
fi

echo 'No usable Linux package was found for this system.' >&2
exit 1
