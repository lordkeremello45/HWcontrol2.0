# Read-only file-scan integration contract

## Responsibility boundary

HWcontrol2.0 owns the user-facing integration and request lifecycle. The
separate HWcontrol-Security component owns file parsing, signature/content
inspection, detection logic, quarantine policy (if later approved), and scanner
updates. This document and the dashboard catalog do **not** implement antivirus
detection.

## File-format routing hints

The dashboard catalog groups these suffixes:

- **Windows:** `.exe`, `.msi`, `.msix`, `.msixbundle`, `.appx`,
  `.appxbundle`, `.dll`, `.sys`, `.cab`, `.msu`, `.zip`, `.7z`,
  `.rar`.
- **macOS:** `.dmg`, `.app`, `.pkg`, `.mpkg`, `.zip`, `.xip`,
  `.dylib`, `.kext`.
- **Linux:** `.deb`, `.rpm`, `.AppImage`, `.flatpak`, `.flatpakref`,
  `.snap`, `.tar`, `.tar.gz`, `.tgz`, `.tar.xz`, `.tar.zst`, `.xz`,
  `.gz`, `.zst`, `.7z`, `.zip`.
- **Common formats:** `.elf`, `.so`, `.o`, `.bin`, `.jar`, `.wasm`,
  supported script suffixes, and files without an extension.

The catalog is a routing/UI hint only. Suffixes can be missing, spoofed, or
misleading. ZIP and other shared formats can appear on multiple operating
systems. Compound archive suffixes must be handled without assuming the
extension establishes the actual file type.

## Required scanner behavior

1. Determine the actual format using file signatures and a safe parser; do not
   trust filename suffixes.
2. Inspect contents even when the suffix is recognized.
3. Include extensionless files in signature-based format detection.
4. Apply resource limits to archives and nested archives, including expanded
   size, entry count, nesting depth, and compression ratio.
5. Prevent path traversal and unsafe links while inspecting archive entries.
6. Report distinct outcomes for clean, malicious, suspicious, unsupported, and
   incomplete/error states. An error must never be reported as clean.
7. Treat publisher signatures as authenticity evidence, not proof that content
   is harmless.

## Current status

- **IMPLEMENTED:** dashboard-side extension catalog and unit tests.
- **NOT IMPLEMENTED by this catalog:** content parsing, malware detection,
  archive extraction, quarantine, real-time monitoring, or a live bridge scan
  endpoint.
- **BLOCKED on integration:** connecting a scanner requires a separately built,
  pinned, verified HWcontrol-Security component and a documented authenticated
  read-only IPC contract. The existing `ScanRequestV1` helper is not, by
  itself, a live scan endpoint.
