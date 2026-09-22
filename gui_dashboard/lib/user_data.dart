import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistent user-owned configuration storage.
///
/// All user configuration is kept outside the installation directory so
/// upgrades/uninstalls do not overwrite the user's settings. Each file has a
/// schema version to allow safe migrations in future releases.
class HWControlUserData {
  HWControlUserData._();

  static const int settingsSchema = 1;
  static const int profilesSchema = 1;
  static const int fanCurvesSchema = 1;
  static const int gameModeSchema = 1;
  static const int stateSchema = 1;

  static Future<Directory> get directory async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}HWControl');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _file(String name) async {
    final dir = await directory;
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  static Future<Map<String, dynamic>> _read(
    String name,
    int expectedSchema,
    Map<String, dynamic> defaults,
  ) async {
    final file = await _file(name);
    if (!await file.exists()) return defaults;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return defaults;
      final root = Map<String, dynamic>.from(decoded);
      if (root['schema'] != expectedSchema) return defaults;
      return root;
    } catch (_) {
      return defaults;
    }
  }

  static Future<void> _write(String name, Map<String, dynamic> value) async {
    final file = await _file(name);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    try {
      await temp.rename(file.path);
    } catch (_) {
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    }
  }

  static Future<Map<String, dynamic>> loadSettings() => _read(
        'settings.json',
        settingsSchema,
        {
          'schema': settingsSchema,
          'settings': {
            'theme': 'dark',
            'animationsEnabled': true,
            'notificationsEnabled': true,
            'temperatureLimit': 85,
          },
        },
      );

  static Future<void> saveSettings({
    required bool darkMode,
    required bool animationsEnabled,
    required bool notificationsEnabled,
    required double temperatureLimit,
  }) =>
      _write('settings.json', {
        'schema': settingsSchema,
        'settings': {
          'theme': darkMode ? 'dark' : 'light',
          'animationsEnabled': animationsEnabled,
          'notificationsEnabled': notificationsEnabled,
          'temperatureLimit': temperatureLimit,
        },
      });

  static Future<void> updateSettings(Map<String, dynamic> patch) async {
    final root = await loadSettings();
    final current = <String, dynamic>{
      if (root['settings'] is Map)
        ...Map<String, dynamic>.from(root['settings'] as Map),
    };
    current.addAll(patch);
    await _write('settings.json', {
      'schema': settingsSchema,
      'settings': current,
    });
  }

  static Future<void> ensureDefaults() async {
    await loadSettings();
    await loadProfiles();
    await loadFanCurves();
    await loadGameMode();
    await loadState();
  }

  static Future<Map<String, Map<String, double>>> loadProfiles() async {
    final root = await _read(
      'profiles.json',
      profilesSchema,
      {'schema': profilesSchema, 'profiles': <String, dynamic>{}},
    );
    final raw = root['profiles'];
    if (raw is! Map) return {};
    final result = <String, Map<String, double>>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final values = Map<String, dynamic>.from(entry.value as Map);
      final fan = (values['fan'] as num?)?.toDouble();
      final ai = (values['ai'] as num?)?.toDouble();
      if (fan == null || ai == null) continue;
      result[entry.key.toString()] = {'fan': fan, 'ai': ai};
    }
    return result;
  }

  static Future<void> saveProfiles(
    Map<String, Map<String, double>> profiles,
  ) =>
      _write('profiles.json', {
        'schema': profilesSchema,
        'profiles': profiles,
      });

  static Future<Map<String, dynamic>> loadFanCurves() => _read(
        'fancurves.json',
        fanCurvesSchema,
        {'schema': fanCurvesSchema, 'curves': <String, dynamic>{}},
      );

  static Future<void> saveFanCurves(Map<String, dynamic> curves) =>
      _write('fancurves.json', {
        'schema': fanCurvesSchema,
        'curves': curves,
      });

  static Future<Map<String, dynamic>> loadGameMode() => _read(
        'game-mode.json',
        gameModeSchema,
        {
          'schema': gameModeSchema,
          'enabled': false,
        },
      );

  static Future<void> saveGameMode(bool enabled) => _write(
        'game-mode.json',
        {'schema': gameModeSchema, 'enabled': enabled},
      );

  static Future<Map<String, dynamic>> loadState() => _read(
        'state.json',
        stateSchema,
        {
          'schema': stateSchema,
          'selectedProfile': null,
        },
      );

  static Future<void> saveState({String? selectedProfile}) => _write(
        'state.json',
        {'schema': stateSchema, 'selectedProfile': selectedProfile},
      );
}
