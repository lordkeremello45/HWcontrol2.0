import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class HWControlModelManager {
  static const modelName = 'gemma-3-1b-it-Q5_K_M.gguf';
  static const modelUrl =
      'https://huggingface.co/second-state/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q5_K_M.gguf?download=true';
  static const modelSha256 =
      '586d772e7f50b36b86bf3d04a1912f880206ef77044c5011107adb8915d97b93';
  static const modelSizeBytes = 851345696;

  static Future<Directory> modelDirectory() async {
    String basePath;
    if (Platform.isWindows) {
      basePath = Platform.environment['LOCALAPPDATA'] ??
          (await getApplicationSupportDirectory()).path;
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      basePath = home != null && home.isNotEmpty
          ? '$home/Library/Application Support'
          : (await getApplicationSupportDirectory()).path;
    } else if (Platform.isLinux) {
      basePath = Platform.environment['XDG_CACHE_HOME'] ??
          '${Platform.environment['HOME'] ?? (await getApplicationSupportDirectory()).path}/.cache';
    } else {
      basePath = (await getApplicationSupportDirectory()).path;
    }
    final directory = Directory(
      '$basePath${Platform.pathSeparator}HWControl${Platform.pathSeparator}models',
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Future<File> modelFile() async {
    final directory = await modelDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}$modelName',
    );
  }

  static Future<bool> isReady() async {
    final file = await modelFile();
    try {
      if (!await file.exists() || await file.length() != modelSizeBytes) {
        return false;
      }
      return await _sha256(file) == modelSha256;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureReady({
    void Function(double progress)? onProgress,
  }) async {
    if (await isReady()) {
      onProgress?.call(1.0);
      return;
    }

    final target = await modelFile();
    final partial = File('${target.path}.part');
    final client = http.Client();
    try {
      if (await partial.exists()) {
        await partial.delete();
      }
      final request = http.Request('GET', Uri.parse(modelUrl))
        ..followRedirects = true
        ..maxRedirects = 5;
      request.headers['User-Agent'] = 'HWControl/0.2 model-manager';
      final response = await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'Model sunucusu HTTP ${response.statusCode} döndürdü.',
        );
      }
      if (response.contentLength != null &&
          response.contentLength! > modelSizeBytes) {
        throw StateError('Model sunucusu beklenenden büyük içerik döndürdü.');
      }

      final sink = partial.openWrite();
      Digest? digest;
      final hasher = sha256.startChunkedConversion(
        ByteConversionSink.withCallback((bytes) {
          digest = Digest(bytes);
        }),
      );
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
          received += chunk.length;
          if (received > modelSizeBytes) {
            throw StateError('Model indirme boyutu sınırı aşıldı.');
          }
          sink.add(chunk);
          hasher.add(chunk);
          onProgress?.call(received / modelSizeBytes);
        }
      } finally {
        hasher.close();
        await sink.flush();
        await sink.close();
      }

      if (received != modelSizeBytes) {
        throw StateError(
          'Model boyutu doğrulanamadı: $received / $modelSizeBytes byte.',
        );
      }
      final actualDigest = digest?.toString();
      if (actualDigest == null || actualDigest != modelSha256) {
        throw StateError(
          'Model SHA-256 doğrulaması başarısız. Beklenen: $modelSha256, alınan: ${actualDigest ?? 'yok'}',
        );
      }

      // Dart's rename cannot replace an existing file on every supported OS.
      // Move the old invalid model aside, install the verified file, then remove
      // the backup. A failed rename attempts to restore the previous model.
      File? backup;
      if (await target.exists()) {
        backup = File('${target.path}.old');
        try {
          if (await backup.exists()) await backup.delete();
        } catch (_) {}
        await target.rename(backup.path);
      }
      try {
        await partial.rename(target.path);
      } catch (_) {
        if (backup != null && await backup.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
      if (backup != null) {
        try {
          if (await backup.exists()) await backup.delete();
        } catch (_) {}
      }
      await _removeLegacyModels(target.parent);
      onProgress?.call(1.0);
    } catch (_) {
      try {
        if (await partial.exists()) {
          await partial.delete();
        }
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<String> _sha256(File file) async {
    Digest? digest;
    final input = sha256.startChunkedConversion(
      ByteConversionSink.withCallback((bytes) {
        digest = Digest(bytes);
      }),
    );
    try {
      await for (final chunk in file.openRead()) {
        input.add(chunk);
      }
    } finally {
      input.close();
    }
    return digest?.toString() ?? '';
  }

  static Future<void> _removeLegacyModels(Directory directory) async {
    const legacyNames = <String>[
      'gemma-2b-it-q4_k_m.gguf',
      'gemma-2b-it-Q4_K_M.gguf',
    ];
    for (final name in legacyNames) {
      try {
        final file = File('${directory.path}${Platform.pathSeparator}$name');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }
}