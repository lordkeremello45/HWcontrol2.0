import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/diagnostics.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnostics writes privacy-safe structured JSONL locally', () async {
    await HWControlDiagnostics.instance.record(
      'test_error',
      error: StateError('example failure'),
      stackTrace: StackTrace.current,
    );

    final directory = await getApplicationSupportDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}diagnostics'
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
  });
}
