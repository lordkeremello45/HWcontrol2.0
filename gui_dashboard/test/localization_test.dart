import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language.json exposes all supported UI locales', () async {
    final raw = await rootBundle.loadString('assets/localization/language.json');
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final locales = (root['locales'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['code'] as String)
        .toSet();

    expect(locales.length, greaterThanOrEqualTo(30));
    expect(locales, containsAll(<String>['en-US', 'en-GB', 'tr-TR', 'ja-JP', 'de-DE', 'fr-FR', 'it-IT', 'es-ES', 'pt-BR', 'zh-CN', 'ko-KR', 'ru-RU', 'ar-SA', 'hi-IN']));

    final localeEntries = (root['locales'] as List<dynamic>).whereType<Map<String, dynamic>>();
    expect(localeEntries.length, locales.length);
    expect(localeEntries.map((entry) => entry['code']).toSet(), locales);

    final translations = root['translations'] as Map<String, dynamic>;
    for (final locale in locales) {
      expect(translations[locale], isA<Map<String, dynamic>>());
      expect((translations[locale] as Map<String, dynamic>)['settings'], isNotEmpty);
      expect((translations[locale] as Map<String, dynamic>)['language'], isNotEmpty);
    }
  });
}
