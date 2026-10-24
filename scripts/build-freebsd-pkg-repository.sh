#!/usr/bin/env sh
# Run on FreeBSD after a native HWcontrol .pkg has been built and tested.
set -eu

if [ "$(uname -s)" != "FreeBSD" ]; then
  echo "This repository builder must run on FreeBSD; pkg(8) metadata is platform-specific." >&2
  exit 1
fi

packages_dir="${1:?Usage: build-freebsd-pkg-repository.sh <directory-with-tested-pkg-files> [output-directory]}"
output_dir="${2:-website/public/pkg}"
: "${PKG_REPO_RSA_KEY_FILE:?Set PKG_REPO_RSA_KEY_FILE to a dedicated RSA repository-signing private key}"

[ -d "$packages_dir" ] || { echo "Package input directory not found: $packages_dir" >&2; exit 1; }
[ -f "$PKG_REPO_RSA_KEY_FILE" ] || { echo "Repository signing key not found." >&2; exit 1; }
mkdir -p "$output_dir"
found=0
for package in "$packages_dir"/*.pkg; do
  [ -f "$package" ] || continue
  name="$(pkg query -F "$package" '%n')"
  arch="$(pkg query -F "$package" '%q')"
  if [ "$name" != "hwcontrol" ]; then
    echo "Refusing unexpected package name '$name' in $package" >&2
    exit 1
  fi
  case "$arch" in
    *:*) : ;; # pkg ABI values commonly include an OS/version suffix
    *) echo "Unexpected or missing package ABI '$arch' in $package" >&2; exit 1 ;;
  esac
  install -m 0644 "$package" "$output_dir/"
  found=1
done
[ "$found" -eq 1 ] || { echo "No tested .pkg artifacts found in $packages_dir" >&2; exit 1; }

# The signing key is used only to sign repository metadata; it is never copied.
pkg repo "$output_dir" "$PKG_REPO_RSA_KEY_FILE"
openssl rsa -in "$PKG_REPO_RSA_KEY_FILE" -pubout -out "$output_dir/hwcontrol-repo.pub"
chmod 0644 "$output_dir/hwcontrol-repo.pub"
echo "Generated signed FreeBSD pkg repository metadata. Validate it on a clean FreeBSD client before publication."
