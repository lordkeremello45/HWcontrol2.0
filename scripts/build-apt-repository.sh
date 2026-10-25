#!/usr/bin/env bash
# Build a signed static APT repository from the newest stable Linux DEB release.
set -euo pipefail

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${APT_GPG_PRIVATE_KEY:?APT_GPG_PRIVATE_KEY secret must be set}"

repo_root="${1:-website/public/apt}"
work_dir="${RUNNER_TEMP:-/tmp}/hwcontrol-apt-repo"
release_json="$work_dir/releases.json"
mkdir -p "$work_dir" "$repo_root/pool/main/h/hwcontrol" "$repo_root/dists/stable/main/binary-amd64"
rm -f "$repo_root/pool/main/h/hwcontrol/"*.deb

gh api --paginate --slurp "repos/$GITHUB_REPOSITORY/releases?per_page=100" | jq 'add' > "$release_json"

tag="$(jq -r '[.[] | select(.draft == false and .prerelease == false) | select(any(.assets[]?; .name | endswith("-Linux-x64.deb")))] | sort_by(.published_at) | last | .tag_name // empty' "$release_json")"
if [[ -z "$tag" ]]; then
  echo "No stable release with a Linux x64 DEB asset was found." >&2
  exit 1
fi

gh release download "$tag" --repo "$GITHUB_REPOSITORY" --pattern '*-Linux-x64.deb' --dir "$repo_root/pool/main/h/hwcontrol"
deb_count="$(find "$repo_root/pool/main/h/hwcontrol" -maxdepth 1 -type f -name '*.deb' | wc -l)"
if [[ "$deb_count" -lt 1 ]]; then
  echo "Release $tag did not yield a DEB package." >&2
  exit 1
fi
while IFS= read -r deb; do
  dpkg-deb --info "$deb" >/dev/null
  package_name="$(dpkg-deb -f "$deb" Package)"
  architecture="$(dpkg-deb -f "$deb" Architecture)"
  version="$(dpkg-deb -f "$deb" Version)"
  [[ "$package_name" == "hwcontrol" ]] || { echo "Unexpected package name: $package_name" >&2; exit 1; }
  [[ "$architecture" == "amd64" ]] || { echo "Unexpected architecture: $architecture" >&2; exit 1; }
  [[ "$version" =~ ^[A-Za-z0-9.+:~_-]+$ ]] || { echo "Unsafe Debian package version: $version" >&2; exit 1; }
  canonical_deb="$repo_root/pool/main/h/hwcontrol/hwcontrol_${version}_amd64.deb"
  if [[ "$deb" != "$canonical_deb" ]]; then
    mv -- "$deb" "$canonical_deb"
  fi
done < <(find "$repo_root/pool/main/h/hwcontrol" -maxdepth 1 -type f -name '*.deb' -print)

pushd "$repo_root" >/dev/null
echo "APT package files found:"
find pool -type f -name '*.deb' -print
# Scan from the pool root so package paths are indexed relative to the repository root.
(cd pool/main/h/hwcontrol && dpkg-scanpackages --arch amd64 . /dev/null pool/main/h/hwcontrol/) > dists/stable/main/binary-amd64/Packages
if ! grep -q '^Package: hwcontrol$' dists/stable/main/binary-amd64/Packages; then
  echo "APT package index is empty or does not contain hwcontrol." >&2
  exit 1
fi
gzip -9 -n -c dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz
apt-ftparchive release dists/stable > dists/stable/Release

gnupg_home="$work_dir/gnupg"
mkdir -m 0700 "$gnupg_home"
export GNUPGHOME="$gnupg_home"
printf '%s' "$APT_GPG_PRIVATE_KEY" | gpg --batch --import
fingerprint="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')"
if [[ -z "$fingerprint" ]]; then
  echo "Could not determine the APT signing key fingerprint." >&2
  exit 1
fi
gpg --batch --yes --local-user "$fingerprint" --clearsign --output "dists/stable/InRelease" "dists/stable/Release"
gpg --batch --yes --local-user "$fingerprint" --armor --detach-sign --output "dists/stable/Release.gpg" "dists/stable/Release"
gpg --batch --export "$fingerprint" > "hwcontrol-archive-keyring.gpg"
printf '%s\n' "$fingerprint" > "KEY-FINGERPRINT.txt"
popd >/dev/null
echo "Built signed APT repository from release $tag (key fingerprint: $fingerprint)."
