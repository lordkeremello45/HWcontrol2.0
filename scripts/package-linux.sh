#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
tag="${1:?Usage: package-linux.sh <release-tag> [build-directory]}"
build_dir="${2:-$repo_root/build}"
version="${tag#v}"
version="${version%-linux}"
if [[ ! "$tag" =~ ^v[A-Za-z0-9.+~_-]+-linux$ || ! "$version" =~ ^[A-Za-z0-9.+:~_-]+$ ]]; then
  echo "Invalid Linux release tag: $tag" >&2
  exit 2
fi
for command in cmake dpkg-deb dpkg-shlibdeps readelf ldd tar zstd; do
  command -v "$command" >/dev/null 2>&1 || { echo "Missing packaging command: $command" >&2; exit 1; }
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/hwcontrol-linux-package.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
asset_root="HWControl-${tag}-Linux-x64"
bundle_root="$work_dir/package/$asset_root"
deb_root="$work_dir/debroot"
cmake_root="$work_dir/cmake-install"
mkdir -p "$bundle_root" "$deb_root" "$cmake_root" "$work_dir/debian"

required_artifacts=(
  "$build_dir/ai_core/ai_engine"
  "$build_dir/audio_core/hwcontrol_audio_probe"
  "$repo_root/bridge-service"
  "$repo_root/security-guardian"
  "$repo_root/security/fetch-status/bridger.key"
  "$repo_root/gui_dashboard/build/linux/x64/release/bundle/hwcontrol_dashboard"
)
for artifact in "${required_artifacts[@]}"; do
  [[ -x "$artifact" ]] || { echo "Missing or non-executable release artifact: $artifact" >&2; exit 1; }
done

DESTDIR="$cmake_root" cmake --install "$build_dir" --prefix /opt/hwcontrol
install -Dm0755 "$cmake_root/opt/hwcontrol/ai_engine" "$bundle_root/ai_engine"
mkdir -p "$bundle_root/lib"
for library_group in libllama.so libggml.so libggml-base.so libggml-cpu.so; do
  matches=("$cmake_root/opt/hwcontrol/lib/$library_group"*)
  [[ -e "${matches[0]}" ]] || { echo "CMake runtime library is missing: $library_group" >&2; exit 1; }
  cp -a "${matches[@]}" "$bundle_root/lib/"
done
install -Dm0755 "$build_dir/audio_core/hwcontrol_audio_probe" "$bundle_root/hwcontrol_audio_probe"
install -Dm0755 "$repo_root/bridge-service" "$bundle_root/bridge-service"
install -Dm0755 "$repo_root/security-guardian" "$bundle_root/security-guardian"
install -Dm0440 "$repo_root/security/fetch-status/bridger.key" "$bundle_root/security/fetch-status/bridger.key"
cp -a "$repo_root/gui_dashboard/build/linux/x64/release/bundle" "$bundle_root/dashboard"
cp "$repo_root/README.md" "$repo_root/SECURITY.md" "$repo_root/THIRD_PARTY_NOTICES" "$repo_root/THIRD_PARTY_NOTICES.md" "$bundle_root/"
cp -a "$repo_root/deploy/linux" "$bundle_root/deploy"

mkdir -p "$deb_root/opt/hwcontrol" "$deb_root/usr/bin" "$deb_root/usr/share/applications" "$deb_root/lib/systemd/system" "$deb_root/DEBIAN"
cp -a "$bundle_root/." "$deb_root/opt/hwcontrol/"
install -Dm0644 "$repo_root/deploy/linux/hwcontrol-bridge.service" "$deb_root/lib/systemd/system/hwcontrol-bridge.service"
install -Dm0644 "$repo_root/deploy/linux/hwcontrol-security-guardian.service" "$deb_root/lib/systemd/system/hwcontrol-security-guardian.service"
cat > "$deb_root/usr/bin/hwcontrol" <<'LAUNCHER'
#!/bin/sh
set -eu
application=/opt/hwcontrol/dashboard/hwcontrol_dashboard
if [ ! -x "$application" ]; then
  echo "hwcontrol: dashboard executable is missing; reinstall the hwcontrol package" >&2
  exit 127
fi
exec "$application" "$@"
LAUNCHER
chmod 0755 "$deb_root/usr/bin/hwcontrol"
cat > "$deb_root/usr/share/applications/hwcontrol.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=HWcontrol2.0
Comment=Hardware monitoring and control
Exec=/usr/bin/hwcontrol
Icon=utilities-system-monitor
Terminal=false
Categories=System;Utility;
DESKTOP

mapfile -d '' -t bundle_files < <(find "$bundle_root" -type f -print0)
elf_files=()
for file in "${bundle_files[@]}"; do
  if readelf -h "$file" >/dev/null 2>&1; then
    dependency_output="$(ldd "$file" 2>&1)" || { printf '%s\n' "$dependency_output" >&2; exit 1; }
    if grep -Fq 'not found' <<< "$dependency_output"; then
      printf 'Unresolved library in %s:\n%s\n' "$file" "$dependency_output" >&2
      exit 1
    fi
    dynamic_section="$(readelf -d "$file" 2>/dev/null || true)"
    if grep -Eq '(RUNPATH|RPATH).*(/workspaces/|/home/runner/work/|/tmp/)' <<< "$dynamic_section"; then
      echo "Build-host path found in ELF search path: $file" >&2
      exit 1
    fi
    elf_files+=("$file")
  fi
done
[[ "${#elf_files[@]}" -gt 0 ]] || { echo "No ELF runtime files were staged." >&2; exit 1; }

cat > "$work_dir/debian/control" <<CONTROL
Source: hwcontrol
Section: utils
Priority: optional
Maintainer: HWControl contributors
Standards-Version: 4.6.2

Package: hwcontrol
Architecture: amd64
Description: HWControl hardware monitoring and control suite
 Cross-platform local hardware monitoring application.
CONTROL

cat > "$deb_root/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -eu
key_dir=/var/lib/hwcontrol
security_dir=$key_dir/security
canary_dir=$security_dir/canary
state_dir=$security_dir/state
key_file=$key_dir/bridge.key
mkdir -p "$canary_dir" "$state_dir"
chmod 0750 "$key_dir"
if [ ! -s "$key_file" ]; then
  umask 077
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n' > "$key_file"
fi
chmod 0600 "$key_file"
if ! getent group hwcontrol-security >/dev/null; then groupadd --system hwcontrol-security; fi
if ! id hwcontrol-security >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin --gid hwcontrol-security hwcontrol-security
fi
install -o root -g hwcontrol-security -m 0440 /opt/hwcontrol/security/fetch-status/bridger.key "$canary_dir/bridger.key"
chown root:hwcontrol-security "$canary_dir"
chmod 0750 "$canary_dir"
chown hwcontrol-security:hwcontrol-security "$state_dir"
chmod 0700 "$state_dir"
if command -v logname >/dev/null 2>&1; then
  user=$(logname 2>/dev/null || true)
  if [ -n "$user" ] && [ "$user" != root ] && id "$user" >/dev/null 2>&1; then
    group=$(id -gn "$user")
    chown root:"$group" "$key_dir"
    chmod 0750 "$key_dir"
  fi
fi
if command -v deb-systemd-helper >/dev/null 2>&1; then
  deb-systemd-helper enable hwcontrol-bridge.service hwcontrol-security-guardian.service >/dev/null
fi
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl restart hwcontrol-bridge.service
  systemctl restart hwcontrol-security-guardian.service
fi
POSTINST
cat > "$deb_root/DEBIAN/prerm" <<'PRERM'
#!/bin/sh
set -eu
if [ "$1" = remove ] || [ "$1" = upgrade ]; then
  if command -v deb-systemd-invoke >/dev/null 2>&1; then
    deb-systemd-invoke stop hwcontrol-security-guardian.service hwcontrol-bridge.service || true
  elif [ -d /run/systemd/system ]; then
    systemctl disable --now hwcontrol-security-guardian.service hwcontrol-bridge.service || true
  fi
  if command -v deb-systemd-helper >/dev/null 2>&1; then
    deb-systemd-helper disable hwcontrol-bridge.service hwcontrol-security-guardian.service >/dev/null || true
  fi
fi
PRERM
cat > "$deb_root/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -eu
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi
POSTRM
chmod 0755 "$deb_root/DEBIAN/postinst" "$deb_root/DEBIAN/prerm" "$deb_root/DEBIAN/postrm"
source_date_epoch="$(git -C "$repo_root" log -1 --format=%ct HEAD)"
find "$bundle_root" "$deb_root" -exec touch -h -d "@$source_date_epoch" {} +
export SOURCE_DATE_EPOCH="$source_date_epoch" LC_ALL=C TZ=UTC
deb_path="$repo_root/HWControl-${tag}-Linux-x64.deb"
dpkg-deb --build --root-owner-group "$deb_root" "$deb_path"
bash "$repo_root/scripts/validate-linux-deb.sh" "$deb_path" "$version"
tar --sort=name --mtime="@$source_date_epoch" --owner=0 --group=0 --numeric-owner -cf "$work_dir/bundle.tar" -C "$work_dir/package" "$asset_root"
gzip -n -c "$work_dir/bundle.tar" > "$repo_root/HWControl-${tag}-Linux-x64.tar.gz"
zstd -q -f "$work_dir/bundle.tar" -o "$repo_root/HWControl-${tag}-Linux-x64.tar.zst"
echo "Built and validated Linux DEB and portable archives for $tag."
shlib_output="$(cd "$work_dir" && dpkg-shlibdeps -O --ignore-missing-info -l"$deb_root/opt/hwcontrol/lib" -e "${elf_files[@]}")"
shlib_depends="$(sed -n 's/^shlibs:Depends=//p' <<< "$shlib_output")"
[[ -n "$shlib_depends" ]] || { echo "dpkg-shlibdeps produced no runtime dependencies." >&2; exit 1; }
cat > "$deb_root/DEBIAN/control" <<CONTROL
Package: hwcontrol
Version: $version
X-HWControl-Packaging-Version: 2
Section: utils
Priority: optional
Architecture: amd64
Maintainer: HWControl contributors
Depends: init-system-helpers, passwd, $shlib_depends
Description: HWControl hardware monitoring and control suite
 Cross-platform local hardware monitoring application.
CONTROL