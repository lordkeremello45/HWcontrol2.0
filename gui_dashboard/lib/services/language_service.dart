import 'dart:ui' as ui;

/// Resolves the user's operating-system language for the application.
///
/// The service deliberately does not contain translations. Translation data
/// remains owned by the bundled localization resources.
class HWControlLanguageService {
  HWControlLanguageService._();

  static const String systemDefault = 'system';

  /// Whether a locale uses a right-to-left writing direction.
  static bool isRightToLeft(String localeCode) {
    final language = localeCode.split('-').first.toLowerCase();
    return const <String>{'ar', 'he', 'fa', 'ur', 'ps', 'sd', 'ug', 'yi'}
        .contains(language);
  }

  static String get systemLocaleCode {
    return _localeCode(ui.PlatformDispatcher.instance.locale);
  }

  static String resolveLocale({
    required String? savedLocale,
    required Iterable<String> supportedCodes,
  }) {
    final supported = supportedCodes.toSet();

    if (savedLocale != null &&
        savedLocale != systemDefault &&
        supported.contains(savedLocale)) {
      return _preferRegionalLocale(savedLocale, supported);
    }

    final systemLocale = _localeCode(ui.PlatformDispatcher.instance.locale);
    if (supported.contains(systemLocale)) {
      return _preferRegionalLocale(systemLocale, supported);
    }

    final languageCode =
        ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    final regionalFallback = _regionalFallback(languageCode, supported);
    if (regionalFallback != null) return regionalFallback;

    return 'en-US';
  }

  static String _preferRegionalLocale(
    String localeCode,
    Set<String> supported,
  ) {
    if (localeCode.contains('-')) return localeCode;
    return _regionalFallback(localeCode.toLowerCase(), supported) ?? localeCode;
  }

  static String? _regionalFallback(
    String languageCode,
    Set<String> supported,
  ) {
    const preferredRegionalCodes = <String, String>{
      'en': 'en-US',
      'es': 'es-ES',
      'pt': 'pt-BR',
      'zh': 'zh-CN',
    };
    final preferred = preferredRegionalCodes[languageCode];
    if (preferred != null && supported.contains(preferred)) return preferred;

    final regional = supported
        .where((code) =>
            code.contains('-') &&
            code.split('-').first.toLowerCase() == languageCode)
        .toList()
      ..sort();
    return regional.isEmpty ? null : regional.first;
  }

  static String _localeCode(ui.Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country == null || country.isEmpty) return language;
    return '$language-$country';
  }
}
