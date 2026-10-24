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
  [[ "$package_name" == "hwcontrol" ]] || { echo "Unexpected package name: $package_name" >&2; exit 1; }
  [[ "$architecture" == "amd64" ]] || { echo "Unexpected architecture: $architecture" >&2; exit 1; }
done < <(find "$repo_root/pool/main/h/hwcontrol" -maxdepth 1 -type f -name '*.deb' -print)

dpkg-scanpackages --arch amd64 pool /dev/null > "$repo_root/dists/stable/main/binary-amd64/Packages"
gzip -9 -n -c "$repo_root/dists/stable/main/binary-amd64/Packages" > "$repo_root/dists/stable/main/binary-amd64/Packages.gz"
apt-ftparchive release "$repo_root/dists/stable" > "$repo_root/dists/stable/Release"

gnupg_home="$work_dir/gnupg"
mkdir -m 0700 "$gnupg_home"
export GNUPGHOME="$gnupg_home"
printf '%s' "$APT_GPG_PRIVATE_KEY" | gpg --batch --import
fingerprint="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')"
if [[ -z "$fingerprint" ]]; then
  echo "Could not determine the APT signing key fingerprint." >&2
  exit 1
fi
gpg --batch --yes --local-user "$fingerprint" --clearsign --output "$repo_root/dists/stable/InRelease" "$repo_root/dists/stable/Release"
gpg --batch --yes --local-user "$fingerprint" --armor --detach-sign --output "$repo_root/dists/stable/Release.gpg" "$repo_root/dists/stable/Release"
gpg --batch --export "$fingerprint" > "$repo_root/hwcontrol-archive-keyring.gpg"
printf '%s\n' "$fingerprint" > "$repo_root/KEY-FINGERPRINT.txt"
echo "Built signed APT repository from release $tag (key fingerprint: $fingerprint)."
