import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/security/scan_file_types.dart';

void main() {
  group('ScanFileTypeCatalog', () {
    test('recognizes Windows installers, executables, drivers and archives', () {
      for (final path in [
        r'C:\Downloads\setup.exe',
        r'C:\Downloads\package.msixbundle',
        r'C:\Drivers\device.sys',
        r'C:\Downloads\archive.rar',
      ]) {
        expect(ScanFileTypeCatalog.hasKnownExtension(path), isTrue, reason: path);
      }
      expect(
        ScanFileTypeCatalog.platformsForPath(r'C:\Downloads\setup.exe'),
        contains(ScanFilePlatform.windows),
      );
    });

    test('recognizes macOS bundles and native libraries', () {
      for (final path in [
        '/Applications/Example.app',
        '/tmp/installer.dmg',
        '/usr/lib/example.dylib',
        '/tmp/archive.xip',
      ]) {
        expect(ScanFileTypeCatalog.hasKnownExtension(path), isTrue, reason: path);
        expect(
          ScanFileTypeCatalog.platformsForPath(path),
          contains(ScanFilePlatform.macOS),
        );
      }
    });

    test('recognizes Linux package formats and compound archive suffixes', () {
      for (final path in [
        '/tmp/package.deb',
        '/tmp/package.AppImage',
        '/tmp/archive.tar.gz',
        '/tmp/archive.tar.zst',
        '/tmp/flatpak.flatpakref',
      ]) {
        expect(ScanFileTypeCatalog.hasKnownExtension(path), isTrue, reason: path);
        expect(
          ScanFileTypeCatalog.platformsForPath(path),
          contains(ScanFilePlatform.linux),
        );
      }
    });

    test('recognizes common binaries, libraries, bytecode and scripts', () {
      for (final path in [
        '/tmp/program.elf',
        '/usr/lib/libexample.so',
        '/tmp/object.o',
        '/tmp/module.wasm',
        '/tmp/archive.jar',
        '/tmp/script.ps1',
        '/tmp/script.sh',
      ]) {
        expect(ScanFileTypeCatalog.hasKnownExtension(path), isTrue, reason: path);
      }
    });

    test('keeps extensionless files in scope for signature detection', () {
      const path = '/tmp/download/no-extension';
      expect(ScanFileTypeCatalog.hasKnownExtension(path), isFalse);
      expect(ScanFileTypeCatalog.requiresSignatureDetection(path), isTrue);
      expect(ScanFileTypeCatalog.requiresContentInspection(path), isTrue);
    });

    test('never treats a known extension as evidence of safety', () {
      expect(
        ScanFileTypeCatalog.requiresContentInspection('/tmp/clean-looking.exe'),
        isTrue,
      );
      expect(
        ScanFileTypeCatalog.requiresContentInspection('/tmp/archive.zip'),
        isTrue,
      );
    });

    test('matches paths case-insensitively and supports Windows separators', () {
      expect(
        ScanFileTypeCatalog.hasKnownExtension(r'C:\TEMP\PAYLOAD.MSIX'),
        isTrue,
      );
    });
  });
}
