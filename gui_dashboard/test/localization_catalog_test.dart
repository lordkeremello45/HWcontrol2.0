import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final englishFile = File('lib/l10n/app_en_US.arb');
  final turkishFile = File('lib/l10n/app_tr.arb');

  test('canonical English localization catalog keeps the 1000-key target visible', () {
    final english = jsonDecode(englishFile.readAsStringSync()) as Map<String, dynamic>;
    final keys = english.keys
        .where((key) => !key.startsWith('@'))
        .toSet();

    // This is a no-regression floor, not a claim that the 1000-key goal is met.
    expect(keys.length, greaterThanOrEqualTo(250));
    expect(keys, containsAll(<String>[
      'wizardTitle',
      'wizardProfileTitle',
      'wizardStartupTitle',
      'wizardSafetyTitle',
      'wizardReadyTitle',
      'wizardSafetyAcknowledge',
      'wizardSummaryDescription',
    ]));
  });

  test('new wizard strings are translated in Turkish, not silently English-only', () {
    final english = jsonDecode(englishFile.readAsStringSync()) as Map<String, dynamic>;
    final turkish = jsonDecode(turkishFile.readAsStringSync()) as Map<String, dynamic>;
    final wizardKeys = english.keys
        .where((key) => key.startsWith('wizard'))
        .where((key) => !key.startsWith('@'));

    for (final key in wizardKeys) {
      expect(turkish[key], isA<String>(), reason: 'Missing Turkish translation: $key');
      expect((turkish[key] as String).trim(), isNotEmpty,
          reason: 'Empty Turkish translation: $key');
    }
  });
}
