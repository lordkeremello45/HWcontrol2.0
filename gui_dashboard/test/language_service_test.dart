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
}
