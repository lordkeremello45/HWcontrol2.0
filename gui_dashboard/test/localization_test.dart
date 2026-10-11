import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language.json exposes unique, valid supported UI locales', () async {
    final raw = await rootBundle.loadString('assets/localization/language.json');
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final localeEntries = (root['locales'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    final localeCodes = localeEntries
        .map((entry) => entry['code'] as String)
        .toList();
    final locales = localeCodes.toSet();

    expect(localeCodes.length, greaterThanOrEqualTo(40));
    expect(locales.length, localeCodes.length,
        reason: 'Locale codes must not be duplicated.');
    expect(root['defaultLocale'], isA<String>());
    expect(locales, contains(root['defaultLocale']));
    expect(locales, containsAll(<String>[
      'en-US', 'en-GB', 'en-CA', 'tr-TR', 'ja-JP', 'de-DE', 'fr-FR',
      'it-IT', 'es-ES', 'es-MX', 'pt-BR', 'pt-PT', 'zh-CN', 'zh-TW',
      'ko-KR', 'ru-RU', 'ar-SA', 'hi-IN', 'ca-ES', 'fil-PH', 'bn-BD',
      'ur-PK',
    ]));

    for (final entry in localeEntries) {
      expect(entry['name'], isA<String>());
      expect((entry['name'] as String).trim(), isNotEmpty);
    }

    final translations = root['translations'] as Map<String, dynamic>;
    expect(translations.keys.toSet(), locales,
        reason: 'Every listed locale must have a translation map.');

    for (final locale in locales) {
      final copy = translations[locale];
      expect(copy, isA<Map<String, dynamic>>(),
          reason: 'Missing translation map for $locale.');
      final values = copy as Map<String, dynamic>;
      for (final key in <String>['settings', 'language']) {
        expect(values[key], isA<String>(),
            reason: '$locale is missing the required "$key" label.');
        expect((values[key] as String).trim(), isNotEmpty,
            reason: '$locale has an empty "$key" label.');
      }
      for (final item in values.entries) {
        expect(item.value, isA<String>(),
            reason: '$locale.${item.key} must be a string.');
        expect((item.value as String).trim(), isNotEmpty,
            reason: '$locale.${item.key} must not be empty.');
      }
    }

    final english = translations['en-US'] as Map<String, dynamic>;
    final turkish = translations['tr-TR'] as Map<String, dynamic>;
    for (final key in <String>[
      'welcomeTitle', 'welcomeGetStarted', 'welcomeOpenDashboard',
      'welcomePreview', 'telemetryHistory', 'advancedTelemetry',
      'releaseOpen',
    ]) {
      expect(english[key], isNotEmpty, reason: 'Missing en-US key: $key');
    }
    expect(turkish['welcomeTitle'], contains("HWcontrol2.0'a"));
    expect(turkish['telemetryHistory'], 'Telemetri geçmişi');
    expect(turkish['advancedTelemetry'], 'Gelişmiş telemetri');
    expect(turkish['releaseOpen'], 'Sürüm sayfasını aç');

    for (final locale in <String>[
      'ca-ES', 'es-MX', 'pt-PT', 'zh-TW', 'fil-PH', 'bn-BD', 'en-CA', 'ur-PK',
    ]) {
      final copy = translations[locale] as Map<String, dynamic>;
      for (final key in <String>[
        'welcomeTitle', 'welcomeDescription', 'welcomeTagline',
        'welcomeGetStarted', 'welcomeOpenDashboard', 'welcomePreview',
      ]) {
        expect(copy[key], isA<String>(),
            reason: '$locale must provide localized onboarding text for $key.');
        expect((copy[key] as String).trim(), isNotEmpty,
            reason: '$locale has empty onboarding text for $key.');
      }
    }
  });
}
