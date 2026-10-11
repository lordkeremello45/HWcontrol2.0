import 'dart:convert';

import 'package:flutter/services.dart';

/// Applies optional prose-style overlays without replacing canonical ARB
/// catalogs. Standard Turkish remains the default and fallback.
class HWControlLocalizationStyleService {
  HWControlLocalizationStyleService._();

  static const String standard = 'standard';
  static const String literary = 'literary';
  static const String _literaryAsset =
      'assets/l10n/variants/tr_TR/literary.json';

  /// These messages must remain direct, unambiguous and operationally precise.
  static const Set<String> _protectedKeys = <String>{
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

  static Future<Map<String, String>> applyStyle({
    required String localeCode,
    required String style,
    required Map<String, String> translations,
  }) async {
    final normalizedLocale = localeCode.replaceAll('_', '-').toLowerCase();
    if (style != literary ||
        !(normalizedLocale == 'tr' || normalizedLocale.startsWith('tr-'))) {
      return Map<String, String>.of(translations);
    }

    try {
      final decoded = jsonDecode(await rootBundle.loadString(_literaryAsset));
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['locale'] != 'tr_TR' ||
          decoded['style'] != literary ||
          decoded['messages'] is! Map<String, dynamic>) {
        return Map<String, String>.of(translations);
      }

      final messages = decoded['messages'] as Map<String, dynamic>;
      final result = Map<String, String>.of(translations);
      for (final entry in messages.entries) {
        final key = entry.key;
        final value = entry.value;
        final canonical = translations[key];
        if (_protectedKeys.contains(key) ||
            canonical == null ||
            value is! String ||
            value.trim().isEmpty ||
            _placeholders(value).difference(_placeholders(canonical)).isNotEmpty ||
            _placeholders(canonical).difference(_placeholders(value)).isNotEmpty) {
          continue;
        }
        result[key] = value;
      }
      return result;
    } catch (_) {
      // Missing or malformed optional style data must never block startup.
      return Map<String, String>.of(translations);
    }
  }

  static Set<String> placeholders(String message) => _placeholders(message);

  static Set<String> _placeholders(String message) => RegExp(
        r'[{]([A-Za-z_][A-Za-z0-9_]*)(?=[,}])',
      ).allMatches(message).map((match) => match.group(1)!).toSet();
}
