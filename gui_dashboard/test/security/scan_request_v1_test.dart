import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/security/scan_request_v1.dart';

void main() {
  late Map<String, dynamic> vector;
  late Map<String, dynamic> rawRequest;
  late ScanRequestV1 request;
  late String secret;

  setUpAll(() {
    vector = jsonDecode(File('test/fixtures/scan_request_v1.json').readAsStringSync()) as Map<String, dynamic>;
    rawRequest = vector['request'] as Map<String, dynamic>;
    secret = vector['secret'] as String;
    request = ScanRequestV1(
      action: rawRequest['action'] as String,
      scopeId: rawRequest['scope_id'] as String,
      mode: rawRequest['mode'] as String,
      timestampMs: rawRequest['timestamp_ms'] as int,
      nonce: rawRequest['nonce'] as String,
      requestId: rawRequest['request_id'] as String,
    );
  });

  test('matches shared canonical payload and HMAC vector', () {
    expect(request.canonicalPayload(), vector['canonical_payload']);
    expect(request.sign(secret), rawRequest['auth']);
    expect(request.verify(secret, rawRequest['auth'] as String), isTrue);
  });

  test('rejects changes to each signed field', () {
    final mutations = <ScanRequestV1>[
      ScanRequestV1(action: request.action, scopeId: 'system-root', mode: request.mode, timestampMs: request.timestampMs, nonce: request.nonce, requestId: request.requestId),
      ScanRequestV1(action: request.action, scopeId: request.scopeId, mode: 'read_write', timestampMs: request.timestampMs, nonce: request.nonce, requestId: request.requestId),
      ScanRequestV1(action: request.action, scopeId: request.scopeId, mode: request.mode, timestampMs: request.timestampMs + 1, nonce: request.nonce, requestId: request.requestId),
      ScanRequestV1(action: request.action, scopeId: request.scopeId, mode: request.mode, timestampMs: request.timestampMs, nonce: '1123456789abcdef0123456789abcdef', requestId: request.requestId),
      ScanRequestV1(action: request.action, scopeId: request.scopeId, mode: request.mode, timestampMs: request.timestampMs, nonce: request.nonce, requestId: 'request-0002'),
    ];
    for (final changed in mutations) {
      expect(changed.verify(secret, rawRequest['auth'] as String), isFalse);
    }
  });

  test('rejects malformed fields and empty keys', () {
    expect(() => ScanRequestV1(action: 'scan', scopeId: 'bad\nscope', mode: 'read_only', timestampMs: 1, nonce: request.nonce, requestId: request.requestId).canonicalPayload(), throwsFormatException);
    expect(() => ScanRequestV1(action: 'scan', scopeId: request.scopeId, mode: 'scan-and-delete', timestampMs: 1, nonce: request.nonce, requestId: request.requestId).canonicalPayload(), throwsFormatException);
    expect(() => request.sign(''), throwsFormatException);
    expect(request.verify('', rawRequest['auth'] as String), isFalse);
    expect(request.verify(secret, 'bad-tag'), isFalse);
  });
}
