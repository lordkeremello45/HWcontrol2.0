import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARB catalogs cover all supported locales and preserve ICU placeholders', () {
    final directory = Directory('lib/l10n');
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'^app_[a-z]{2,3}_[A-Z]{2}\.arb$')
            .hasMatch(file.uri.pathSegments.last))
        .toList();
    expect(files.length, 40);

    final catalogs = <String, Map<String, dynamic>>{};
    for (final file in files) {
      final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final locale = catalog['@@locale'] as String;
      expect(catalogs.containsKey(locale), isFalse, reason: 'Duplicate locale $locale');
      catalogs[locale] = catalog;
      expect(catalog['localeName'], isA<String>());
      expect((catalog['localeName'] as String).trim(), isNotEmpty);
    }

    final source = catalogs['en_US']!;
    final sourceKeys = source.keys
        .where((key) => !key.startsWith('@') && key != '@@locale')
        .toSet();
    expect(sourceKeys.length, greaterThanOrEqualTo(219);
    const fallbackOnlyKeys = <String>{
      'securityBlockedTitle',
      'securityBlockedDescription',
      'securityBlockedRecommendation',
      'securityCloseApplication',
    };
    for (final locale in catalogs.entries) {
      final keys = locale.value.keys
          .where((key) => !key.startsWith('@') && key != '@@locale')
          .toSet();
      expect(
        keys,
        containsAll(sourceKeys.difference(fallbackOnlyKeys)),
        reason: 'Missing base strings in ${locale.key}',
      );
    }

    for (final key in sourceKeys) {
      final value = source[key];
      if (value is! String) continue;
      final placeholders = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}')
          .allMatches(value)
          .map((match) => match.group(1)!)
          .toSet();
      if (placeholders.isNotEmpty) {
        final metadata = source['@$key'] as Map<String, dynamic>;
        final declared =
            (metadata['placeholders'] as Map<String, dynamic>).keys.toSet();
        expect(declared, placeholders,
            reason: 'Placeholder metadata mismatch for $key');
      }
    }

    expect(source['securityBlockedTitle'], isA<String>());
    expect(catalogs['tr_TR']!['securityBlockedTitle'], isA<String>());
  });
}
