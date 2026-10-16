/// Validated, persisted UI personalization settings.
class HWControlUiPreferences {
  HWControlUiPreferences._();

  static const int defaultAccentColorValue = 0xFF64D8CB;

  /// Accent colors are deliberately an allowlist; imported/corrupt JSON cannot
  /// inject arbitrary values into the theme.
  static const List<int> accentColorValues = <int>[
    defaultAccentColorValue,
    0xFF4FC3F7,
    0xFF9575CD,
    0xFFFFB74D,
    0xFF81C784,
  ];

  static int resolveAccentColor(Object? value) {
    if (value is int && accentColorValues.contains(value)) {
      return value;
    }
    return defaultAccentColorValue;
  }

  static String accentColorLabel(int value, {required bool turkish}) {
    switch (resolveAccentColor(value)) {
      case 0xFF4FC3F7:
        return turkish ? 'Mavi' : 'Blue';
      case 0xFF9575CD:
        return turkish ? 'Mor' : 'Purple';
      case 0xFFFFB74D:
        return turkish ? 'Kehribar' : 'Amber';
      case 0xFF81C784:
        return turkish ? 'Yeşil' : 'Green';
      default:
        return turkish ? 'Turkuaz' : 'Teal';
    }
  }
}
