import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/diagnostics.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  test('diagnostics writes privacy-safe structured JSONL locally', () async {
    final temp = await Directory.systemTemp.createTemp('hwcontrol_diag_test_');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);

    await HWControlDiagnostics.instance.record(
      'test_error',
      error: StateError('example failure'),
      stackTrace: StackTrace.current,
    );

    final file = File(
      '\${temp.path}\${Platform.pathSeparator}diagnostics'
      '\${Platform.pathSeparator}events.jsonl',
    );
    expect(await file.exists(), isTrue);

    final line = (await file.readAsLines()).last;
    final event = jsonDecode(line) as Map<String, dynamic>;
    expect(event['event'], 'test_error');
    expect(event['level'], 'error');
    expect(event['errorType'], 'StateError');
    expect(event['message'], contains('example failure'));
    expect(event.containsKey('hardware'), isFalse);
    expect(event.containsKey('settings'), isFalse);

    await temp.delete(recursive: true);
  });
}
