import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/services/audio/piper_tts_service.dart';

void main() {
  group('PiperTtsService local configuration', () {
    late Directory temp;
    late File executable;
    late File model;
    late File config;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('hwcontrol-piper-test-');
      executable = File('${temp.path}${Platform.pathSeparator}piper');
      model = File('${temp.path}${Platform.pathSeparator}voice.onnx');
      config = File('${model.path}.json');
      await executable.writeAsString('test executable placeholder');
      await model.writeAsBytes(<int>[1, 2, 3]);
      await config.writeAsString('{"audio": {"sample_rate": 22050}}');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('accepts a local model only when its matching config exists', () async {
      final service = PiperTtsService();

      expect(
        await service.isConfigured(
          executablePath: executable.path,
          modelPath: model.path,
        ),
        isTrue,
      );

      await config.delete();
      expect(
        await service.isConfigured(
          executablePath: executable.path,
          modelPath: model.path,
        ),
        isFalse,
      );
    });

    test('rejects a malformed model config', () async {
      await config.writeAsString('not json');
      final service = PiperTtsService();

      expect(
        await service.isConfigured(
          executablePath: executable.path,
          modelPath: model.path,
        ),
        isFalse,
      );
    });

    test('rejects empty speech before starting a process', () async {
      final service = PiperTtsService();

      await expectLater(
        service.speak(
          text: '   ',
          executablePath: executable.path,
          modelPath: model.path,
        ),
        throwsArgumentError,
      );
    });

    test('rejects oversized speech input', () async {
      final service = PiperTtsService();

      await expectLater(
        service.speak(
          text: 'x' * 4001,
          executablePath: executable.path,
          modelPath: model.path,
        ),
        throwsArgumentError,
      );
    });
  });
}
