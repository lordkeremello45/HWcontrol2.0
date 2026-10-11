import 'package:flutter_test/flutter_test.dart';

import '../lib/services/language_service.dart';

void main() {
  test('keeps an explicitly selected supported locale', () {
    expect(
      HWControlLanguageService.resolveLocale(
        savedLocale: 'tr-TR',
        supportedCodes: const ['en-US', 'tr-TR', 'de-DE'],
      ),
      'tr-TR',
    );
  });

  test('maps a base language selection to its regional catalog when available', () {
    expect(
      HWControlLanguageService.resolveLocale(
        savedLocale: 'ar',
        supportedCodes: const ['ar', 'ar-SA', 'en-US'],
      ),
      'ar-SA',
    );
    expect(
      HWControlLanguageService.resolveLocale(
        savedLocale: 'en',
        supportedCodes: const ['en', 'en-CA', 'en-US'],
      ),
      'en-US',
    );
  });

  test('resolves System Default from the current platform locale', () {
    final systemCode = HWControlLanguageService.systemLocaleCode;
    final result = HWControlLanguageService.resolveLocale(
      savedLocale: HWControlLanguageService.systemDefault,
      supportedCodes: [systemCode, 'en-US'],
    );
    expect(result, systemCode);
  });

  test('falls back to en-US when no bundled resource matches', () {
    expect(
      HWControlLanguageService.resolveLocale(
        savedLocale: HWControlLanguageService.systemDefault,
        supportedCodes: const ['en-US', 'zz-ZZ'],
      ),
      'en-US',
    );
  });
  test('detects right-to-left locales by language subtag', () {
    expect(HWControlLanguageService.isRightToLeft('ar-SA'), isTrue);
    expect(HWControlLanguageService.isRightToLeft('ur-PK'), isTrue);
    expect(HWControlLanguageService.isRightToLeft('he-IL'), isTrue);
    expect(HWControlLanguageService.isRightToLeft('en-US'), isFalse);
    expect(HWControlLanguageService.isRightToLeft('tr-TR'), isFalse);
  });

}
