#!/bin/sh
set -eu

REPO='lordkeremello45/HWcontrol2.0'
API="https://api.github.com/repos/$REPO/releases"
TMP_DIR="${TMPDIR:-/tmp}/hwcontrol-installer"
mkdir -p "$TMP_DIR"

printf '\nHWControl macOS Installer\n'
printf '%s\n' 'Resolving the latest stable Apple Silicon release...'
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 is required to safely parse the GitHub release metadata. Install python3 and rerun.' >&2; exit 1; }

release_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: HWControl-Installer' "$API")"
tag="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); c=[x for x in r if x.get("tag_name","").endswith("-macos") and not x.get("draft") and not x.get("prerelease")]; c.sort(key=lambda x:x.get("published_at") or x.get("created_at") or "", reverse=True); print(c[0]["tag_name"] if c else "")')"
[ -n "$tag" ] || { echo 'No stable macOS release is currently available.' >&2; exit 1; }
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

verify_extra_hashes(){
  base="$(basename "$pkg")"
  sha512_url="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); x=next(x for x in r if x["tag_name"]==sys.argv[1]); print(next((a["browser_download_url"] for a in x["assets"] if a["name"]=="SHA512SUMS.txt"), ""))' "$tag")"
  sha3_url="$(printf '%s' "$release_json" | python3 -c 'import json,sys; r=json.load(sys.stdin); x=next(x for x in r if x["tag_name"]==sys.argv[1]); print(next((a["browser_download_url"] for a in x["assets"] if a["name"]=="SHA3-512SUMS.txt"), ""))' "$tag")"
  if [ -n "$sha512_url" ]; then
    sha512_file="$TMP_DIR/SHA512SUMS.txt"; curl -fL -o "$sha512_file" "$sha512_url"
    expected="$(awk -v f="$base" '$2 == f || $2 == "*" f {print $1; exit}' "$sha512_file")"
    if [ -n "$expected" ]; then actual="$(shasum -a 512 "$pkg" | awk '{print $1}')"; [ "$actual" = "$expected" ] || { echo 'SHA-512 verification failed. The installer was not launched.' >&2; exit 1; }; echo 'SHA-512 verification: OK'; else echo "SHA-512 manifest has no entry for $base; continuing."; fi
  else echo 'SHA-512 manifest: not published; continuing with SHA-256.'; fi
  if [ -n "$sha3_url" ]; then
    if ! command -v openssl >/dev/null; then echo 'SHA3-512 verification skipped: OpenSSL is not available.'; return 0; fi
    sha3_file="$TMP_DIR/SHA3-512SUMS.txt"; curl -fL -o "$sha3_file" "$sha3_url"
    expected="$(awk -v f="$base" '$2 == f || $2 == "*" f {print $1; exit}' "$sha3_file")"
    if [ -n "$expected" ]; then actual="$(openssl dgst -sha3-512 -r "$pkg" | awk '{print $1}')"; [ "$actual" = "$expected" ] || { echo 'SHA3-512 verification failed. The installer was not launched.' >&2; exit 1; }; echo 'SHA3-512 verification: OK'; else echo "SHA3-512 manifest has no entry for $base; continuing."; fi
  else echo 'SHA3-512 manifest: not published; continuing with SHA-256.'; fi
}
verify_extra_hashes

echo "Starting HWControl $tag installer..."
sudo installer -pkg "$pkg" -target /
echo 'HWControl installation finished.'
