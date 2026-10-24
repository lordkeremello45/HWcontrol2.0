import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/services/bridge_line_decoder.dart';

void main() {
  test('preserves UTF-8 characters split across socket chunks', () async {
    final controller = StreamController<List<int>>();
    final lines = <String>[];
    final completed = decodeUtf8Lines(controller.stream).listen(lines.add).asFuture<void>();
    const expected = '{"message":"İşlem tamamlandı"}';
    final encoded = utf8.encode('$expected\n');
    final split = encoded.indexOf(0xC4) + 1; // Split the two-byte "İ" sequence.
    expect(split, greaterThan(0));

    controller.add(encoded.sublist(0, split));
    controller.add(encoded.sublist(split));
    await controller.close();
    await completed;

    expect(lines, equals(<String>[expected]));
  });
}
