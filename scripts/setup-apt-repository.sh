#!/usr/bin/env bash
# Register the official HWcontrol2.0 APT repository on Debian/Ubuntu amd64.
set -euo pipefail

readonly REPO_BASE="https://lordkeremello45.github.io/HWcontrol2.0/apt"
readonly EXPECTED_FINGERPRINT="17B2AAC6F057A3AD4C43EF4BD150613F605FA463"
readonly KEYRING_PATH="/usr/share/keyrings/hwcontrol-archive-keyring.gpg"
readonly SOURCES_PATH="/etc/apt/sources.list.d/hwcontrol.sources"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this setup script with sudo: sudo bash $0" >&2
  exit 1
fi

if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
  echo "HWcontrol APT repository currently supports amd64 only." >&2
  exit 1
fi

for command in curl gpg dpkg apt-get install; do
  if ! command -v "${command%% *}" >/dev/null 2>&1; then
    echo "Required command is missing: ${command%% *}" >&2
    exit 1
  fi
done

tmp_key="$(mktemp)"
trap 'rm -f "$tmp_key"' EXIT
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "$REPO_BASE/hwcontrol-archive-keyring.gpg" --output "$tmp_key"

actual_fingerprint="$(gpg --batch --show-keys --with-colons "$tmp_key" |
  awk -F: '$1 == "fpr" { print $10; exit }')"
if [[ "$actual_fingerprint" != "$EXPECTED_FINGERPRINT" ]]; then
  echo "APT signing-key fingerprint mismatch; refusing to trust this key." >&2
  echo "Expected: $EXPECTED_FINGERPRINT" >&2
  echo "Received: ${actual_fingerprint:-<none>}" >&2
  exit 1
fi

install -D -o root -g root -m 0644 "$tmp_key" "$KEYRING_PATH"
cat > "$SOURCES_PATH" <<EOF
Types: deb
URIs: $REPO_BASE
Suites: stable
Components: main
Architectures: amd64
Signed-By: $KEYRING_PATH
EOF
chmod 0644 "$SOURCES_PATH"

apt-get update
echo
echo "HWcontrol APT repository registered and package indexes updated."
echo "Install HWcontrol with: sudo apt install hwcontrol"
