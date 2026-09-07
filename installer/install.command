#!/bin/sh
set -eu

REPO='lordkeremello45/HWcontrol2.0'
API="https://api.github.com/repos/$REPO/releases"
TMP_DIR="${TMPDIR:-/tmp}/hwcontrol-installer"
mkdir -p "$TMP_DIR"

printf '\nHWControl macOS Installer\n'
printf '%s\n' 'Resolving the latest stable Apple Silicon release...'

release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: HWControl-Installer' "$API")"
tag="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(next(x["tag_name"] for x in r if x["tag_name"].endswith("-macos") and not x["draft"] and not x["prerelease"]))')"
asset_info="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); x=next(x for x in r if x["tag_name"]==sys.argv[1]); p=next((a for a in x["assets"] if a["name"].endswith(".pkg")),None); s=next((a for a in x["assets"] if a["name"].endswith(".sha256")),None); print((p["name"] if p else "")+"\t"+(p["browser_download_url"] if p else "")+"\t"+(s["name"] if s else "")+"\t"+(s["browser_download_url"] if s else ""))' "$tag")"
TAB=$(printf '\t')
IFS="$TAB" read -r pkg_name pkg_url sha_name sha_url <<EOF
$asset_info
EOF

if [ -z "$pkg_name" ] || [ -z "$pkg_url" ]; then
  echo "The latest macOS release ($tag) does not publish a PKG." >&2
  exit 1
fi
if [ -z "$sha_url" ]; then
  echo "The latest macOS release ($tag) has no SHA-256 manifest. Installation is blocked." >&2
  exit 1
fi

pkg="$TMP_DIR/$pkg_name"
sha_file="$TMP_DIR/$sha_name"
curl -fL -o "$pkg" "$pkg_url"
curl -fL -o "$sha_file" "$sha_url"

expected="$(awk -v f="$(basename "$pkg")" '$2 == f || $2 == "*" f {print $1; exit}' "$sha_file")"
if [ -z "$expected" ]; then
  echo "No SHA-256 entry for $(basename "$pkg") was found. Installation is blocked." >&2
  exit 1
fi
actual="$(shasum -a 256 "$pkg" | awk '{print $1}')"
[ "$actual" = "$expected" ] || { echo 'SHA-256 verification failed. The installer was not launched.' >&2; exit 1; }
echo 'SHA-256 verification: OK'

echo "Starting HWControl $tag installer..."
sudo installer -pkg "$pkg" -target /
echo 'HWControl installation finished.'
