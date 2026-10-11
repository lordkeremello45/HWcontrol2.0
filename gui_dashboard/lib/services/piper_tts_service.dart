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

  Future<bool> isConfigured({
    required String executablePath,
    required String modelPath,
  }) async {
    final executable = await _resolveExecutable(executablePath);
    return executable != null && await File(modelPath).exists();
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
    if (!await File(modelPath).exists()) {
      throw StateError(
        'Piper voice model was not found. Set the path to a local .onnx model.',
      );
    }

    _speaking = true;
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
      await completed.timeout(const Duration(seconds: 90));
    } finally {
      _speaking = false;
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

  Future<void> dispose() async {
    await _player.dispose();
  }
}
