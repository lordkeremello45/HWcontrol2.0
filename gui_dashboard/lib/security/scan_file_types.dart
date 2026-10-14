/// File-format hints for HWcontrol2.0's future read-only scan integration.
///
/// This catalog is not a malware scanner and never treats an extension as proof
/// of a file's format or safety. The HWcontrol-Security component must inspect
/// file signatures and parsed content independently.
enum ScanFilePlatform { windows, macOS, linux, common }

class ScanFileTypeCatalog {
  ScanFileTypeCatalog._();

  static const Map<ScanFilePlatform, Set<String>> extensions = {
    ScanFilePlatform.windows: {
      '.exe', '.msi', '.msix', '.msixbundle', '.appx', '.appxbundle',
      '.dll', '.sys', '.cab', '.msu', '.zip', '.7z', '.rar',
    },
    ScanFilePlatform.macOS: {
      '.dmg', '.app', '.pkg', '.mpkg', '.zip', '.xip', '.dylib', '.kext',
    },
    ScanFilePlatform.linux: {
      '.deb', '.rpm', '.appimage', '.flatpak', '.flatpakref', '.snap',
      '.tar', '.tar.gz', '.tgz', '.tar.xz', '.tar.zst', '.xz', '.gz',
      '.zst', '.7z', '.zip',
    },
    ScanFilePlatform.common: {
      '.elf', '.so', '.o', '.bin', '.jar', '.wasm',
    },
  };

  static const Set<String> scriptExtensions = {
    '.sh', '.bash', '.zsh', '.fish', '.ps1', '.psm1', '.bat', '.cmd',
    '.js', '.mjs', '.cjs', '.py', '.rb', '.pl', '.php', '.lua',
  };

  /// Returns all known extension matches for a path, including overlapping
  /// platform formats such as ZIP.
  static Set<ScanFilePlatform> platformsForPath(String path) {
    final name = _basename(path).toLowerCase();
    final matches = <ScanFilePlatform>{};
    for (final entry in extensions.entries) {
      if (entry.value.any((extension) => name.endsWith(extension))) {
        matches.add(entry.key);
      }
    }
    if (scriptExtensions.any(name.endsWith)) {
      matches.add(ScanFilePlatform.common);
    }
    return Set.unmodifiable(matches);
  }

  /// Whether a path has a known extension. This is only a routing hint.
  static bool hasKnownExtension(String path) =>
      platformsForPath(path).isNotEmpty;

  /// Every file, including a recognized extension, requires content inspection.
  static bool requiresContentInspection(String path) => true;

  /// Signature/type detection is mandatory for every file, including paths
  /// with recognized suffixes. An extension is never evidence of file format.
  static bool requiresSignatureDetection(String path) => true;

  static String _basename(String path) {
    final normalized = path.replaceAll(String.fromCharCode(92), '/');
    final separator = normalized.lastIndexOf('/');
    return separator < 0 ? normalized : normalized.substring(separator + 1);
  }
}
