import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Versioned request authentication for the future read-only security scan.
///
/// This helper is intentionally not wired into HWcontrol2.0's live Bridge
/// protocol. Do not use it to authenticate existing hardware-control commands.
class ScanRequestV1 {
  const ScanRequestV1({
    required this.action,
    required this.scopeId,
    required this.mode,
    required this.timestampMs,
    required this.nonce,
    required this.requestId,
  });

  static const version = 'HWSECURITY-SCAN-V1';
  static final _scopePattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
  static final _noncePattern = RegExp(r'^[0-9a-fA-F]{32}$');
  static final _requestPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  final String action;
  final String scopeId;
  final String mode;
  final int timestampMs;
  final String nonce;
  final String requestId;

  String canonicalPayload() {
    if (action != 'scan') {
      throw const FormatException('unsupported scan action');
    }
    if (!_scopePattern.hasMatch(scopeId)) {
      throw const FormatException('invalid scope_id');
    }
    if (mode != 'read_only') {
      throw const FormatException('unsupported scan mode');
    }
    if (timestampMs <= 0) {
      throw const FormatException('timestamp_ms must be positive');
    }
    if (!_noncePattern.hasMatch(nonce)) {
      throw const FormatException('nonce must be 32 hexadecimal characters');
    }
    if (!_requestPattern.hasMatch(requestId)) {
      throw const FormatException('invalid request_id');
    }
    return <String>[
      version,
      action,
      scopeId,
      mode,
      timestampMs.toString(),
      nonce.toLowerCase(),
      requestId,
    ].join('\n');
  }

  String sign(String secret) {
    if (secret.isEmpty) {
      throw const FormatException('empty authentication key');
    }
    final bytes = utf8.encode(canonicalPayload());
    return Hmac(sha256, utf8.encode(secret)).convert(bytes).toString();
  }

  bool verify(String secret, String auth) {
    if (secret.isEmpty || auth.length != 64 || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(auth)) {
      return false;
    }
    try {
      final expected = sign(secret);
      // Compare fixed-length ASCII tags without an early-exit character loop.
      var difference = 0;
      final supplied = auth.toLowerCase();
      for (var i = 0; i < expected.length; i++) {
        difference |= expected.codeUnitAt(i) ^ supplied.codeUnitAt(i);
      }
      return difference == 0;
    } on FormatException {
      // Malformed requests are untrusted input and must fail verification.
      return false;
    }
  }
}
