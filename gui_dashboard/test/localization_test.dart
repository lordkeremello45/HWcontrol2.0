import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARB catalogs cover supported locales and preserve ICU placeholders', () {
    final directory = Directory('lib/l10n');
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'^app_[a-z]{2,3}_[A-Z]{2}\\.arb$')
            .hasMatch(file.uri.pathSegments.last))
        .toList();
    expect(files.length, 40);

    final catalogs = <String, Map<String, dynamic>>{};
    for (final file in files) {
      final catalog = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final locale = catalog['@@locale'] as String;
      expect(catalogs.containsKey(locale), isFalse, reason: 'Duplicate locale $locale');
      catalogs[locale] = catalog;
      expect(catalog['localeDisplayName'], isA<String>());
      expect((catalog['localeDisplayName'] as String).trim(), isNotEmpty);
      expect(file.uri.pathSegments.last, 'app_${locale}.arb');
    }

    final source = catalogs['en_US']!;
    final sourceKeys = source.keys
        .where((key) => !key.startsWith('@') && key != '@@locale')
        .toSet();
    expect(sourceKeys.length, greaterThanOrEqualTo(233));

    const fallbackOnlyKeys = <String>{
      'securityBlockedTitle',
      'securityBlockedDescription',
      'securityBlockedRecommendation',
      'securityCloseApplication',
      'updateStatusNotChecked',
      'updateStatusNoRelease',
      'updateStatusCurrent',
      'updateStatusAvailable',
      'updateStatusCheckFailed',
      'updateStatusDownloading',
      'updateStatusVerified',
      'updateStatusVerificationFailed',
      'updateReleaseReady',
    };

    for (final locale in catalogs.entries) {
      final catalog = locale.value;
      final keys = catalog.keys
          .where((key) => !key.startsWith('@') && key != '@@locale')
          .toSet();
      expect(
        keys,
        containsAll(sourceKeys.difference(fallbackOnlyKeys)),
        reason: 'Missing base strings in ${locale.key}',
      );

      for (final key in keys.intersection(sourceKeys)) {
        final sourceText = source[key];
        final translatedText = catalog[key];
        if (sourceText is! String || translatedText is! String) continue;
        final sourcePlaceholders = _placeholders(sourceText);
        expect(
          _placeholders(translatedText),
          sourcePlaceholders,
          reason: 'Placeholder mismatch for $key in ${locale.key}',
        );
        if (sourcePlaceholders.isNotEmpty) {
          final metadata = catalog['@$key'];
          expect(metadata, isA<Map<String, dynamic>>(),
              reason: 'Missing metadata for $key in ${locale.key}');
          final declared =
              (metadata as Map<String, dynamic>)['placeholders'];
          expect(declared, isA<Map<String, dynamic>>());
          expect(
            (declared as Map<String, dynamic>).keys.toSet(),
            sourcePlaceholders,
            reason: 'Placeholder metadata mismatch for $key in ${locale.key}',
          );
        }
      }
    }

    for (final key in sourceKeys) {
      final value = source[key];
      if (value is! String) continue;
      final placeholders = _placeholders(value);
      if (placeholders.isNotEmpty) {
        final metadata = source['@$key'] as Map<String, dynamic>;
        final declared =
            (metadata['placeholders'] as Map<String, dynamic>).keys.toSet();
        expect(declared, placeholders,
            reason: 'Template placeholder metadata mismatch for $key');
      }
    }

    for (final locale in catalogs.entries) {
      expect(locale.value['anomalyCount'], contains(', plural,'),
          reason: 'Anomaly count must use ICU plural rules in ${locale.key}');
      expect(locale.value['iterations'], contains(', plural,'),
          reason: 'Benchmark iterations must use ICU plural rules in ${locale.key}');
    }

    final mapFile = File('lib/l10n/app_localizations_map.dart').readAsStringSync();
    final mappedKeys = RegExp(r"'([A-Za-z0-9_]+)':\\s*([A-Za-z0-9_]+),")
        .allMatches(mapFile)
        .where((match) => match.group(1) == match.group(2))
        .map((match) => match.group(1)!)
        .toSet();
    final expectedMapKeys = sourceKeys
        .where((key) => !(source['@$key'] is Map &&
            (source['@$key'] as Map).containsKey('placeholders')))
        .toSet();
    expect(mappedKeys, expectedMapKeys,
        reason: 'The legacy key adapter must stay in sync with the ARB template');

    final runtimeRoots = <Directory>[Directory('lib'), Directory('test')];
    final legacyAssetName = 'language' + '.json';
    final legacyAssetPath = 'assets/' + 'localization/';
    for (final root in runtimeRoots) {
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final sourceText = entity.readAsStringSync();
        expect(sourceText.contains(legacyAssetName), isFalse,
            reason: 'Legacy localization asset reference remains in ${entity.path}');
        expect(sourceText.contains(legacyAssetPath), isFalse,
            reason: 'Legacy localization asset path remains in ${entity.path}');
      }
    }
  });
}

Set<String> _placeholders(String message) => RegExp(r'\\{([A-Za-z_][A-Za-z0-9_]*)(?=[,}])')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();
