#!/usr/bin/env bash
set -euo pipefail

REPO='lordkeremello45/HWcontrol2.0'
API="https://api.github.com/repos/$REPO/releases"
TMP_DIR="${TMPDIR:-/tmp}/hwcontrol-installer"
mkdir -p "$TMP_DIR"

printf '\nHWControl Linux Installer\n'
printf '%s\n' 'Resolving the latest Linux release...'

release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: HWControl-Installer' "$API")"
tag="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); print(next(x["tag_name"] for x in r if x["tag_name"].endswith("-linux") and not x["draft"]))')"
deb_url="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); x=next(x for x in r if x["tag_name"].endswith("-linux") and not x["draft"]); print(next((a["browser_download_url"] for a in x["assets"] if a["name"].endswith(".deb")), ""))')"
sha_url="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); x=next(x for x in r if x["tag_name"].endswith("-linux") and not x["draft"]); print(next((a["browser_download_url"] for a in x["assets"] if a["name"].endswith(".sha256")), ""))')"

if [ -z "$deb_url" ]; then
  echo "No Debian package is available for the latest Linux release ($tag)." >&2
  exit 1
fi

deb="$TMP_DIR/HWControl-$tag.deb"
curl -fL -o "$deb" "$deb_url"

if [ -n "$sha_url" ]; then
  expected="$(curl -fsSL "$sha_url" | awk '/\.deb$/ {print $1; exit}')"
  if [ -n "$expected" ]; then
    actual="$(sha256sum "$deb" | awk '{print $1}')"
    [ "$actual" = "$expected" ] || { echo 'SHA-256 verification failed. The package was not installed.' >&2; exit 1; }
    echo 'SHA-256 verification: OK'
  fi
fi

echo "Installing HWControl $tag..."
sudo apt-get install -y "$deb"
echo 'HWControl installation finished.'
