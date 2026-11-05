import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/services/companion_binary_locator.dart';

void main() {
  group('hasBridgeServiceBinary', () {
    test('finds the Linux bridge in the package root above dashboard', () async {
      final root = await Directory.systemTemp.createTemp('hwcontrol-linux-');
      addTearDown(() => root.delete(recursive: true));
      final dashboard = Directory(
        '${root.path}${Platform.pathSeparator}dashboard',
      );
      await dashboard.create();
      await File(
        '${root.path}${Platform.pathSeparator}bridge-service',
      ).writeAsString('');

      expect(
        await hasBridgeServiceBinary(
          executablePath:
              '${dashboard.path}${Platform.pathSeparator}hwcontrol_dashboard',
          isWindows: false,
        ),
        isTrue,
      );
    });

    test('finds the macOS bridge outside Contents/MacOS and the app bundle', () async {
      final root = await Directory.systemTemp.createTemp('hwcontrol-macos-');
      addTearDown(() => root.delete(recursive: true));
      final executableDirectory = Directory([
        root.path,
        'HWControl.app',
        'Contents',
        'MacOS',
      ].join(Platform.pathSeparator));
      await executableDirectory.create(recursive: true);
      await File(
        '${root.path}${Platform.pathSeparator}bridge-service',
      ).writeAsString('');

      expect(
        await hasBridgeServiceBinary(
          executablePath:
              '${executableDirectory.path}${Platform.pathSeparator}HWControl',
          isWindows: false,
        ),
        isTrue,
      );
    });

    test('finds the macOS AI engine in the package root above the app bundle', () async {
      final root = await Directory.systemTemp.createTemp('hwcontrol-macos-ai-');
      addTearDown(() => root.delete(recursive: true));
      final executableDirectory = Directory([
        root.path,
        'HWControl.app',
        'Contents',
        'MacOS',
      ].join(Platform.pathSeparator));
      await executableDirectory.create(recursive: true);
      final engine = File(
        '${root.path}${Platform.pathSeparator}ai_engine',
      );
      await engine.writeAsString('');

      final found = await findCompanionBinary(
        executablePath:
            '${executableDirectory.path}${Platform.pathSeparator}HWControl',
        binaryNames: const <String>['ai_engine'],
      );
      expect(found?.path, engine.path);
    });

    test('finds the Windows bridge executable beside the dashboard', () async {
      final root = await Directory.systemTemp.createTemp('hwcontrol-windows-');
      addTearDown(() => root.delete(recursive: true));
      await File(
        '${root.path}${Platform.pathSeparator}bridge-service.exe',
      ).writeAsString('');

      expect(
        await hasBridgeServiceBinary(
          executablePath:
              '${root.path}${Platform.pathSeparator}HWControl.exe',
          isWindows: true,
        ),
        isTrue,
      );
    });

    test('does not search beyond the configured parent depth', () async {
      final root = await Directory.systemTemp.createTemp('hwcontrol-bound-');
      addTearDown(() => root.delete(recursive: true));
      final executableDirectory = Directory([
        root.path,
        'one',
        'two',
        'three',
        'four',
      ].join(Platform.pathSeparator));
      await executableDirectory.create(recursive: true);
      await File(
        '${root.path}${Platform.pathSeparator}bridge-service',
      ).writeAsString('');

      expect(
        await hasBridgeServiceBinary(
          executablePath:
              '${executableDirectory.path}${Platform.pathSeparator}HWControl',
          isWindows: false,
        ),
        isFalse,
      );
    });
  });
}
