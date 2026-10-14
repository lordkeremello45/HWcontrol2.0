import 'package:flutter_test/flutter_test.dart';
import 'package:gui_dashboard/ui_preferences.dart';

void main() {
  group('HWControlUiPreferences', () {
    test('accepts only allowlisted accent colors', () {
      for (final color in HWControlUiPreferences.accentColorValues) {
        expect(HWControlUiPreferences.resolveAccentColor(color), color);
      }
    });

    test('uses the default for malformed or unknown values', () {
      expect(
        HWControlUiPreferences.resolveAccentColor(null),
        HWControlUiPreferences.defaultAccentColorValue,
      );
      expect(
        HWControlUiPreferences.resolveAccentColor('0xFF4FC3F7'),
        HWControlUiPreferences.defaultAccentColorValue,
      );
      expect(
        HWControlUiPreferences.resolveAccentColor(0xFFFFFFFF),
        HWControlUiPreferences.defaultAccentColorValue,
      );
    });

    test('provides localized labels for the palette', () {
      expect(
        HWControlUiPreferences.accentColorLabel(0xFF9575CD, turkish: true),
        'Mor',
      );
      expect(
        HWControlUiPreferences.accentColorLabel(0xFF9575CD, turkish: false),
        'Purple',
      );
    });
  });
}
