import 'package:flutter_test/flutter_test.dart';
import '../lib/extension_api.dart';

void main() {
  test('extension manifest round-trips safely', () {
    const manifest = HWControlExtensionManifest(
      id: 'example.sensor',
      name: 'Example Sensor',
      version: '1.0.0',
      capabilities: <String>['telemetry'],
    );
    final parsed = HWControlExtensionManifest.fromJson(manifest.toJson());
    expect(parsed?.id, 'example.sensor');
    expect(parsed?.capabilities, contains('telemetry'));
  });

  test('malformed manifest is rejected', () {
    expect(HWControlExtensionManifest.fromJson(<String, dynamic>{
      'id': '',
      'name': 'bad',
      'version': '1.0.0',
      'capabilities': <String>[],
    }), isNull);
  });
}
