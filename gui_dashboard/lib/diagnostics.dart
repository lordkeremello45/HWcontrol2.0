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
  Future<File>? _crashHistoryFileFuture;
  Future<File>? _sessionFileFuture;

  Future<File> _logFile() {
    return _logFileFuture ??= _resolveLogFile();
  }

  Future<File> _resolveCrashHistoryFile() async {
    final directory = _baseDirectory ?? await getApplicationSupportDirectory();
    final diagnosticsDirectory =
        Directory('${directory.path}${Platform.pathSeparator}diagnostics');
    await diagnosticsDirectory.create(recursive: true);
    return File(
      '${diagnosticsDirectory.path}${Platform.pathSeparator}crash-history.jsonl',
    );
  }

  Future<File> _resolveSessionFile() async {
    final directory = _baseDirectory ?? await getApplicationSupportDirectory();
    final diagnosticsDirectory =
        Directory('${directory.path}${Platform.pathSeparator}diagnostics');
    await diagnosticsDirectory.create(recursive: true);
    return File(
      '${diagnosticsDirectory.path}${Platform.pathSeparator}session.json',
    );
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

  Future<void> initializeSession({required String applicationVersion}) async {
    try {
      final file = await (_sessionFileFuture ??= _resolveSessionFile());
      var previousUnclean = false;
      if (await file.exists()) {
        try {
          final previous = jsonDecode(await file.readAsString());
          previousUnclean = previous is Map<String, dynamic> &&
              previous['cleanExit'] != true;
        } catch (_) {
          previousUnclean = true;
        }
      }
      await file.writeAsString(
        jsonEncode({
          'startedAt': DateTime.now().toUtc().toIso8601String(),
          'cleanExit': false,
          'applicationVersion': applicationVersion,
          'platform': Platform.operatingSystem,
          'architecture': Platform.operatingSystemVersion,
        }),
        flush: true,
      );
      if (previousUnclean) {
        await record('previous_session_unclean',
            level: 'warning',
            error: StateError('Previous dashboard session did not record a clean exit.'));
      }
    } catch (_) {}
  }

  Future<void> markSessionCleanExit() async {
    try {
      final file = await (_sessionFileFuture ??= _resolveSessionFile());
      if (!await file.exists()) return;
      Map<String, dynamic> session = <String, dynamic>{};
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) session = decoded;
      } catch (_) {}
      session['cleanExit'] = true;
      session['endedAt'] = DateTime.now().toUtc().toIso8601String();
      await file.writeAsString(jsonEncode(session), flush: true);
    } catch (_) {}
  }

  Future<void> recordCrash(
    Object error,
    StackTrace stackTrace, {
    String event = 'uncaught_crash',
    String applicationVersion = 'unknown',
  }) async {
    try {
      await record(event, error: error, stackTrace: stackTrace);
      final file =
          await (_crashHistoryFileFuture ??= _resolveCrashHistoryFile());
      final payload = <String, dynamic>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': event,
        'applicationVersion': applicationVersion,
        'platform': Platform.operatingSystem,
        'architecture': Platform.operatingSystemVersion,
        'errorType': error.runtimeType.toString(),
        'message': _safeMessage(error.toString()),
        'stackTrace': _safeStackTrace(stackTrace),
      };
      await file.writeAsString(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trimFile(file, maxLines: 100);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> readCrashHistory() async {
    try {
      final file =
          await (_crashHistoryFileFuture ??= _resolveCrashHistoryFile());
      if (!await file.exists()) return <Map<String, dynamic>>[];
      final lines = await file.readAsLines();
      final result = <Map<String, dynamic>>[];
      for (final line in lines.reversed) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic>) result.add(decoded);
        } catch (_) {}
      }
      return result.take(100).toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
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
        payload['stackTrace'] = _safeStackTrace(stackTrace);
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

  String _safeStackTrace(StackTrace stackTrace) {
    const maxLength = 12000;
    final value = stackTrace.toString();
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}…';
  }

  Future<void> _trimFile(File file, {required int maxLines}) async {
    try {
      final lines = await file.readAsLines();
      if (lines.length <= maxLines) return;
      await file.writeAsString(
        '${lines.sublist(lines.length - maxLines).join('\n')}\n',
        flush: true,
      );
    } catch (_) {}
  }

  String _safeMessage(String message) {
    const maxLength = 2000;
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}…';
  }
}
