import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Optional offline speech synthesis through the Piper CLI.
///
/// Piper and a compatible ONNX voice model must be installed locally. No text
/// is sent to a network service. The executable is launched without a shell.
class PiperTtsService {
  PiperTtsService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _speaking = false;
  bool _cancelRequested = false;
  Process? _activeProcess;
  Completer<void>? _stopCompleter;

  Future<bool> isConfigured({
    required String executablePath,
    required String modelPath,
  }) async {
    final executable = await _resolveExecutable(executablePath);
    return executable != null && await _hasVoiceModel(modelPath);
  }

  Future<void> speak({
    required String text,
    required String executablePath,
    required String modelPath,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) throw ArgumentError('Speech text must not be empty.');
    if (cleanText.length > 4000) {
      throw ArgumentError('Speech text exceeds the 4000-character safety limit.');
    }
    if (_speaking) throw StateError('Speech is already in progress.');

    final executable = await _resolveExecutable(executablePath);
    if (executable == null) {
      throw StateError(
        'Piper executable was not found. Install Piper or set its executable path.',
      );
    }
    if (!await _hasVoiceModel(modelPath)) {
      throw StateError(
        'Piper voice model was not found. Set the path to a local .onnx model.',
      );
    }

    _speaking = true;
    _cancelRequested = false;
    _stopCompleter = Completer<void>();
    String? outputPath;
    Process? process;
    try {
      final temp = await getTemporaryDirectory();
      outputPath =
          '${temp.path}${Platform.pathSeparator}hwcontrol-piper-${DateTime.now().microsecondsSinceEpoch}.wav';
      process = await Process.start(
        executable,
        <String>['--model', modelPath, '--output_file', outputPath],
        runInShell: false,
      );
      _activeProcess = process;
      // Drain both streams to avoid blocking if Piper emits diagnostics.
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      process.stdin.writeln(cleanText);
      await process.stdin.flush();
      await process.stdin.close();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          process?.kill();
          throw TimeoutException('Piper speech synthesis timed out.');
        },
      );
      if (_cancelRequested) return;
      if (exitCode != 0) {
        throw StateError('Piper exited with code $exitCode.');
      }
      final output = File(outputPath);
      if (!await output.exists() || await output.length() < 44) {
        throw StateError('Piper did not produce a valid WAV file.');
      }
      await _player.stop();
      final completed = _player.onPlayerComplete.first;
      await _player.play(DeviceFileSource(outputPath));
      await Future.any<void>([
        completed.timeout(const Duration(seconds: 90)),
        _stopCompleter!.future,
      ]);
    } finally {
      _speaking = false;
      _activeProcess = null;
      _stopCompleter = null;
      if (outputPath != null) {
        try {
          final output = File(outputPath);
          if (await output.exists()) await output.delete();
        } catch (_) {
          // Temporary audio cleanup is best-effort.
        }
      }
    }
  }

  Future<bool> _hasVoiceModel(String modelPath) async {
    final model = File(modelPath);
    if (!await model.exists() || await model.length() == 0) return false;
    // Piper requires the matching .onnx.json configuration beside the model.
    final config = File('$modelPath.json');
    if (!await config.exists() || await config.length() == 0) return false;
    try {
      final decoded = await config.readAsString();
      return decoded.trimLeft().startsWith('{');
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveExecutable(String configuredPath) async {
    final candidates = <String>[
      configuredPath.trim(),
      Platform.environment['HWCONTROL_PIPER_EXECUTABLE']?.trim() ?? '',
    ];
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      try {
        if (await File(candidate).exists()) return candidate;
      } catch (_) {
        // Continue to PATH lookup.
      }
    }

    final command = Platform.isWindows ? 'where.exe' : 'which';
    try {
      final result = await Process.run(
        command,
        const ['piper'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        final first = (result.stdout as String)
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        if (first.isNotEmpty && await File(first).exists()) return first;
      }
    } catch (_) {
      // Piper is optional; the dashboard must continue without it.
    }
    return null;
  }

  Future<void> stop() async {
    _cancelRequested = true;
    final stopCompleter = _stopCompleter;
    if (stopCompleter != null && !stopCompleter.isCompleted) {
      stopCompleter.complete();
    }
    _activeProcess?.kill();
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
