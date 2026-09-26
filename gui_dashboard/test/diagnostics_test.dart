import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnostics writes privacy-safe structured JSONL locally', () async {
    final root = await Directory.systemTemp.createTemp('hwcontrol-diagnostics-test-');
    addTearDown(() => root.delete(recursive: true));
    final diagnostics = HWControlDiagnostics(baseDirectory: root);

    await diagnostics.record(
      'test_error',
      error: StateError('example failure'),
      stackTrace: StackTrace.current,
    );

    final file = File(
      '${root.path}${Platform.pathSeparator}diagnostics'
      '${Platform.pathSeparator}events.jsonl',
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

    await diagnostics.recordCrash(
      StateError('crash example'),
      StackTrace.current,
      applicationVersion: 'test',
    );
    final crashes = await diagnostics.readCrashHistory();
    expect(crashes, isNotEmpty);
    expect(crashes.first['applicationVersion'], 'test');
    expect(crashes.first['message'], contains('crash example'));

    await diagnostics.initializeSession(applicationVersion: 'test');
    await diagnostics.markSessionCleanExit();
    final session = jsonDecode(await File(
      '${root.path}${Platform.pathSeparator}diagnostics'
      '${Platform.pathSeparator}session.json',
    ).readAsString()) as Map<String, dynamic>;
    expect(session['cleanExit'], isTrue);
  });
}
