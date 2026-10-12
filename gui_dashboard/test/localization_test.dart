import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:hwcontrol_dashboard/l10n/app_localizations.dart';
import 'package:hwcontrol_dashboard/l10n/app_localizations_map.dart';
import 'package:hwcontrol_dashboard/services/localization_style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ARB catalogs cover supported locales and preserve ICU placeholders', () {
    final directory = Directory('lib/l10n');
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'^app_[a-z]{2,3}_[A-Z]{2}[.]arb$')
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
      expect(file.uri.pathSegments.last, 'app_$locale.arb');
    }

    final languageCodes = catalogs.keys
        .map((locale) => locale.split('_').first)
        .toSet();
    for (final languageCode in languageCodes) {
      final fallbackFile = File('lib/l10n/app_$languageCode.arb');
      expect(
        fallbackFile.existsSync(),
        isTrue,
        reason: 'Missing base-language fallback catalog for $languageCode',
      );
      final fallbackCatalog =
          jsonDecode(fallbackFile.readAsStringSync()) as Map<String, dynamic>;
      expect(fallbackCatalog['@@locale'], languageCode);
      expect(fallbackCatalog['localeDisplayName'], isA<String>());
    }

    final source = catalogs['en_US']!;
    final sourceKeys = source.keys
        .where((key) => !key.startsWith('@') && key != '@@locale')
        .toSet();
    expect(sourceKeys.length, greaterThanOrEqualTo(235));

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
    final mappedKeys = RegExp(r"'([A-Za-z0-9_]+)':[ ]*([A-Za-z0-9_]+),")
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

    final allDartFiles = <File>[];
    for (final root in runtimeRoots) {
      allDartFiles.addAll(
        root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      );
    }
    final usedLegacyKeys = <String>{};
    for (final file in allDartFiles) {
      final sourceText = file.readAsStringSync();
      usedLegacyKeys.addAll(
        RegExp(r"_tr\(\s*'([A-Za-z0-9_]+)'")
            .allMatches(sourceText)
            .map((match) => match.group(1)!),
      );
    }
    final installerText = File('lib/installer_main.dart').readAsStringSync();
    final explicitlyHandledParameterizedKeys =
        RegExp(r"case '([A-Za-z0-9_]+)'")
            .allMatches(installerText)
            .map((match) => match.group(1)!)
            .toSet();
    final unmappedCalls = usedLegacyKeys.difference(
      mappedKeys.union(explicitlyHandledParameterizedKeys),
    );
    expect(
      unmappedCalls,
      isEmpty,
      reason: 'A key-based UI call has no ARB-generated message mapping',
    );

    final legacyAssetName = 'language.json';
    final legacyAssetPath = 'assets/localization/';
    final legacyAssetFile = File('$legacyAssetPath$legacyAssetName');
    expect(legacyAssetFile.existsSync(), isFalse,
        reason: 'The old runtime localization asset must remain removed');
    expect(
      File('pubspec.yaml').readAsStringSync().contains(legacyAssetPath),
      isFalse,
      reason: 'pubspec.yaml must not bundle the old localization directory',
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('generate: true'),
      reason: 'Flutter gen-l10n must be enabled',
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('flutter_localizations:'),
      reason: 'Flutter platform widgets must use the localization package',
    );
    expect(
      File('l10n.yaml').readAsStringSync(),
      contains('template-arb-file: app_en_US.arb'),
      reason: 'The canonical localization template must be ARB',
    );
    for (final entity in Directory('lib')
        .listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final sourceText = entity.readAsStringSync();
      expect(sourceText.contains(legacyAssetName), isFalse,
          reason: 'Legacy localization asset reference remains in ${entity.path}');
      expect(sourceText.contains(legacyAssetPath), isFalse,
          reason: 'Legacy localization asset path remains in ${entity.path}');
    }
  });
  test('literary Turkish overlay preserves canonical keys and placeholders', () async {
    final canonical = jsonDecode(
      File('lib/l10n/app_tr_TR.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final overlay = jsonDecode(
      File('assets/l10n/variants/tr_TR/literary.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(overlay['schemaVersion'], 1);
    expect(overlay['locale'], 'tr_TR');
    expect(overlay['style'], HWControlLocalizationStyleService.literary);
    final messages = overlay['messages'] as Map<String, dynamic>;

    const protectedKeys = <String>{
      'automationSafetyNote',
      'benchmarkDisclaimer',
      'hardwareControlUnavailableNote',
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
      'installerCheckFailed',
      'installerModelDownloadFailed',
    };

    for (final entry in messages.entries) {
      expect(canonical[entry.key], isA<String>(),
          reason: 'Unknown or non-string ARB key: ${entry.key}');
      expect(entry.value, isA<String>(),
          reason: 'Overlay value must be a string: ${entry.key}');
      expect(protectedKeys.contains(entry.key), isFalse,
          reason: 'Protected message must not be stylistically overridden: ${entry.key}');
      expect(
        HWControlLocalizationStyleService.placeholders(entry.value as String),
        HWControlLocalizationStyleService.placeholders(canonical[entry.key] as String),
        reason: 'Placeholder mismatch for ${entry.key}',
      );
    }

    final turkish = lookupAppLocalizations(const Locale('tr', 'TR')).toStringMap();
    final literary = await HWControlLocalizationStyleService.applyStyle(
      localeCode: 'tr-TR',
      style: HWControlLocalizationStyleService.literary,
      translations: turkish,
    );
    expect(literary['dashboard'], 'Gösterge paneli');
    expect(literary['welcomeDescription'], messages['welcomeDescription']);

    final standard = await HWControlLocalizationStyleService.applyStyle(
      localeCode: 'tr-TR',
      style: HWControlLocalizationStyleService.standard,
      translations: turkish,
    );
    expect(standard['dashboard'], turkish['dashboard']);

    final english = lookupAppLocalizations(const Locale('en', 'US')).toStringMap();
    final englishWithLiteraryPreference =
        await HWControlLocalizationStyleService.applyStyle(
      localeCode: 'en-US',
      style: HWControlLocalizationStyleService.literary,
      translations: english,
    );
    expect(englishWithLiteraryPreference, english);
  });

  test('generated ICU messages handle plural forms in multiple locales', () {
    final english = lookupAppLocalizations(const Locale('en', 'US'));
    expect(english.anomalyCount(0), 'No anomalies');
    expect(english.anomalyCount(1), '1 anomaly');
    expect(english.anomalyCount(2), '2 anomalies');
    expect(english.iterations(1), '1 iteration');
    expect(english.iterations(3), '3 iterations');
    expect(
      english.automationRuleSummary('CPU temperature', 70, 50),
      'CPU temperature ≥ 70 °C → fan 50%',
    );
    expect(
      english.dashboardSpeechSummary('50.0', '20', '30'),
      'Dashboard. CPU temperature 50.0 degrees Celsius. CPU usage 20 percent. GPU usage 30 percent.',
    );

    final turkish = lookupAppLocalizations(const Locale('tr', 'TR'));
    expect(turkish.anomalyCount(0), 'Anomali yok');
    expect(turkish.anomalyCount(2), '2 anomali');
    expect(
      turkish.automationRuleSummary('İşlemci sıcaklığı', 70, 50),
      'İşlemci sıcaklığı ≥ 70 °C → fan %50',
    );
    expect(
      turkish.dashboardSpeechSummary('50.0', '20', '30'),
      'Ana ekran. İşlemci sıcaklığı 50.0 derece Celsius. İşlemci kullanımı yüzde 20. Ekran kartı kullanımı yüzde 30.',
    );

    final polish = lookupAppLocalizations(const Locale('pl', 'PL'));
    expect(polish.iterations(1), '1 iteracja');
    expect(polish.iterations(2), '2 iteracje');
    expect(polish.iterations(5), '5 iteracji');
  });

}

Set<String> _placeholders(String message) => RegExp(r'[{]([A-Za-z_][A-Za-z0-9_]*)(?=[,}])')
    .allMatches(message)
    .map((match) => match.group(1)!)
    .toSet();
