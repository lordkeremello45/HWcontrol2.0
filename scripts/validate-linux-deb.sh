#!/usr/bin/env bash
set -euo pipefail

deb_path="${1:?Usage: validate-linux-deb.sh <package.deb> <expected-version>}"
expected_version="${2:?Usage: validate-linux-deb.sh <package.deb> <expected-version>}"
for command in dpkg-deb readelf ldd; do
  command -v "$command" >/dev/null 2>&1 || { echo "Missing command: $command" >&2; exit 1; }
done
[[ -s "$deb_path" ]] || { echo "DEB is missing or empty: $deb_path" >&2; exit 1; }

package="$(dpkg-deb -f "$deb_path" Package)"
version="$(dpkg-deb -f "$deb_path" Version)"
architecture="$(dpkg-deb -f "$deb_path" Architecture)"
depends="$(dpkg-deb -f "$deb_path" Depends)"
[[ "$package" == hwcontrol ]] || { echo "Unexpected package name: $package" >&2; exit 1; }
[[ "$version" == "$expected_version" ]] || { echo "Unexpected package version: $version" >&2; exit 1; }
[[ "$architecture" == amd64 ]] || { echo "Unexpected package architecture: $architecture" >&2; exit 1; }
[[ "$depends" == *init-system-helpers* && "$depends" == *passwd* ]] || { echo "Service/user management dependencies are missing: ${depends:-<empty>}" >&2; exit 1; }
grep -Eq 'libgtk-3-0(t64)?' <<< "$depends" || { echo "Flutter GTK dependency is missing: ${depends:-<empty>}" >&2; exit 1; }

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/hwcontrol-deb-validate.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
dpkg-deb -x "$deb_path" "$work_dir/root"
root="$work_dir/root"
required_paths=(
  usr/bin/hwcontrol
  usr/share/applications/hwcontrol.desktop
  lib/systemd/system/hwcontrol-bridge.service
  lib/systemd/system/hwcontrol-security-guardian.service
  opt/hwcontrol/ai_engine
  opt/hwcontrol/hwcontrol_audio_probe
  opt/hwcontrol/bridge-service
  opt/hwcontrol/security-guardian
  opt/hwcontrol/security/fetch-status/bridger.key
  opt/hwcontrol/dashboard/hwcontrol_dashboard
  opt/hwcontrol/dashboard/data/icudtl.dat
  opt/hwcontrol/dashboard/data/flutter_assets/AssetManifest.bin
  opt/hwcontrol/dashboard/lib/libflutter_linux_gtk.so
  opt/hwcontrol/lib/libllama.so.0
  opt/hwcontrol/lib/libggml.so.0
  opt/hwcontrol/lib/libggml-base.so.0
  opt/hwcontrol/lib/libggml-cpu.so.0
)
for relative_path in "${required_paths[@]}"; do
  [[ -e "$root/$relative_path" ]] || { echo "Required package path missing: /$relative_path" >&2; exit 1; }
done
for executable in usr/bin/hwcontrol opt/hwcontrol/ai_engine opt/hwcontrol/hwcontrol_audio_probe opt/hwcontrol/bridge-service opt/hwcontrol/security-guardian opt/hwcontrol/dashboard/hwcontrol_dashboard; do
  [[ -x "$root/$executable" ]] || { echo "Package executable missing or not executable: /$executable" >&2; exit 1; }
done
sh -n "$root/usr/bin/hwcontrol"

while IFS= read -r -d '' binary; do
  readelf -h "$binary" >/dev/null 2>&1 || continue
  dependency_output="$(ldd "$binary" 2>&1)" || { printf '%s\n' "$dependency_output" >&2; exit 1; }
  if grep -Fq 'not found' <<< "$dependency_output"; then
    printf 'Unresolved library in %s:\n%s\n' "${binary#"$root"}" "$dependency_output" >&2
    exit 1
  fi
  dynamic_section="$(readelf -d "$binary" 2>/dev/null || true)"
  if grep -Eq '(RUNPATH|RPATH).*(/workspaces/|/home/runner/work/|/tmp/)' <<< "$dynamic_section"; then
    echo "Build-host path found in ELF search path: ${binary#"$root"}" >&2
    exit 1
  fi
done < <(find "$root/opt/hwcontrol" -type f -print0)

echo "Validated $package $version ($architecture), launcher, desktop/services, Flutter assets, native libraries and dependencies."