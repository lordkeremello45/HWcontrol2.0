import 'dart:ui' as ui;

/// Resolves the user's operating-system language for the application.
///
/// The service deliberately does not contain translations. Translation data
/// remains owned by the bundled localization resources.
class HWControlLanguageService {
  HWControlLanguageService._();

  static const String systemDefault = 'system';

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
      return savedLocale;
    }

    final systemLocale = _localeCode(ui.PlatformDispatcher.instance.locale);
    if (supported.contains(systemLocale)) return systemLocale;

    final languageCode =
        ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    for (final code in supported) {
      if (code.split('-').first.toLowerCase() == languageCode) {
        return code;
      }
    }

    return 'en-US';
  }

  static String _localeCode(ui.Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country == null || country.isEmpty) return language;
    return '$language-$country';
  }
}
