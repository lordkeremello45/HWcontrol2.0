import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local-only diagnostics sink.
///
/// This deliberately has no network dependency. It stores structured JSONL
/// diagnostics in the application support directory so the dashboard remains
/// functional when cloud services are unavailable or disabled.
class HWControlDiagnostics {
  HWControlDiagnostics({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  HWControlDiagnostics._() : _baseDirectory = null;

  static final HWControlDiagnostics instance = HWControlDiagnostics._();

  final Directory? _baseDirectory;
  Future<File>? _logFileFuture;

  Future<File> _logFile() {
    return _logFileFuture ??= _resolveLogFile();
  }

  Future<File> _resolveLogFile() async {
    final directory = _baseDirectory ?? await getApplicationSupportDirectory();
    final diagnosticsDirectory =
        Directory('${directory.path}${Platform.pathSeparator}diagnostics');
    await diagnosticsDirectory.create(recursive: true);
    return File(
      '${diagnosticsDirectory.path}${Platform.pathSeparator}events.jsonl',
    );
  }

  Future<void> record(
    String event, {
    String level = 'error',
    Object? error,
    StackTrace? stackTrace,
  }) async {
    try {
      final file = await _logFile();
      final payload = <String, dynamic>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'level': level,
        'event': event,
      };

      // Keep diagnostics privacy-safe: record error type/message and stack
      // trace, but never attach application settings or hardware telemetry.
      if (error != null) {
        payload['errorType'] = error.runtimeType.toString();
        payload['message'] = _safeMessage(error.toString());
      }
      if (stackTrace != null) {
        payload['stackTrace'] = stackTrace.toString();
      }

      await file.writeAsString(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Diagnostics must never become a startup/runtime dependency.
    }
  }

  Future<void> info(String event) => record(event, level: 'info');

  Future<void> warning(String event, {Object? error}) =>
      record(event, level: 'warning', error: error);

  Future<void> reportError(
    Object error,
    StackTrace stackTrace, {
    String event = 'uncaught_error',
  }) =>
      record(event, error: error, stackTrace: stackTrace);

  String _safeMessage(String message) {
    const maxLength = 2000;
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}…';
  }
}
