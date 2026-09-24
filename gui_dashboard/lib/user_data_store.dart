import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistent per-user application data.
///
/// Layout:
///   HWControl/config/  -> settings, profiles, fan curves, UI preferences
///   HWControl/data/    -> telemetry and other runtime/user data
///
/// Legacy flat files are read once from the previous HWControl directory and
/// migrated into the new config/data layout. Security-sensitive bridge keys
/// remain under the platform service locations and are not copied here.
class HWControlUserDataStore {
  static const int currentSchema = 2;

  Future<Directory> get rootDirectory async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}HWControl',
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get configDirectory async {
    final root = await rootDirectory;
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}config',
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get dataDirectory async {
    final root = await rootDirectory;
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}data',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Kept for callers that need to enumerate configuration files.
  Future<File> configFile(String name) async {
    final dir = await configDirectory;
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<File> dataFile(String name) async {
    final dir = await dataDirectory;
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<File> _legacyFile(String name) async {
    final root = await rootDirectory;
    return File('${root.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> _readJsonFile(File target) async {
    if (!await target.exists()) return null;
    try {
      final decoded = jsonDecode(await target.readAsString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readJsonObject(String name) async {
    final target = await configFile(name);
    final current = await _readJsonFile(target);
    if (current != null) return current;

    // Backward compatibility for the pre-v2 flat HWControl directory.
    final legacy = await _legacyFile(name);
    final old = await _readJsonFile(legacy);
    if (old != null) {
      try {
        await writeJsonObject(name, old);
        await legacy.delete();
      } catch (_) {
        // A failed migration must not prevent the application from starting.
      }
    }
    return old;
  }

  Future<void> writeJsonObject(
    String name,
    Map<String, dynamic> value,
  ) async {
    final target = await configFile(name);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.old');
    final encoded = const JsonEncoder.withIndent('  ').convert(value);

    await temporary.writeAsString('$encoded\n', flush: true);

    if (await backup.exists()) {
      await backup.delete();
    }
    if (await target.exists()) {
      await target.rename(backup.path);
    }

    try {
      await temporary.rename(target.path);
    } catch (_) {
      if (await backup.exists() && !await target.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }

    if (await backup.exists()) {
      await backup.delete();
    }
  }

  Future<Map<String, dynamic>> readProfiles() async {
    final root = await readJsonObject('profiles.json');
    if (root == null) return <String, dynamic>{};

    // Backward-compatible read of the original pre-schema profile format.
    if (root['schema'] == null) return root;

    final profiles = root['profiles'];
    return profiles is Map
        ? Map<String, dynamic>.from(profiles)
        : <String, dynamic>{};
  }

  Future<void> writeProfiles(Map<String, dynamic> profiles) {
    return writeJsonObject('profiles.json', <String, dynamic>{
      'schema': currentSchema,
      'profiles': profiles,
    });
  }

  Future<Map<String, dynamic>> readSettings() async {
    final root = await readJsonObject('settings.json');
    if (root == null) return <String, dynamic>{};

    final settings = root['settings'];
    return settings is Map
        ? Map<String, dynamic>.from(settings)
        : <String, dynamic>{};
  }

  Future<void> writeSettings(Map<String, dynamic> settings) {
    return writeJsonObject('settings.json', <String, dynamic>{
      'schema': currentSchema,
      'settings': settings,
    });
  }

  Future<Map<String, dynamic>> readFanCurves() async {
    final root = await readJsonObject('fancurves.json');
    if (root == null) return <String, dynamic>{};

    final curves = root['curves'];
    return curves is Map
        ? Map<String, dynamic>.from(curves)
        : <String, dynamic>{};
  }

  Future<void> writeFanCurves(Map<String, dynamic> curves) {
    return writeJsonObject('fancurves.json', <String, dynamic>{
      'schema': currentSchema,
      'curves': curves,
    });
  }

  /// Simple UI preferences intentionally use INI because they are flat
  /// key/value settings. Complex application state stays in JSON.
  Future<Map<String, String>> readUiPreferences() async {
    final file = await configFile('ui.ini');
    var text = '';
    if (await file.exists()) {
      text = await file.readAsString();
    } else {
      final legacy = await _legacyFile('ui.ini');
      if (await legacy.exists()) {
        text = await legacy.readAsString();
        try {
          await file.writeAsString(text, flush: true);
          await legacy.delete();
        } catch (_) {}
      }
    }

    final values = <String, String>{};
    var section = '';
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim();
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      values[section.isEmpty ? key : '$section.$key'] = value;
    }
    return values;
  }

  Future<void> writeUiPreferences(Map<String, String> values) async {
    final file = await configFile('ui.ini');
    final lines = <String>['; HWControl UI preferences', '[ui]'];
    final keys = values.keys.toList()..sort();
    for (final key in keys) {
      final normalized = key.startsWith('ui.') ? key.substring(3) : key;
      lines.add('$normalized=${values[key] ?? ''}');
    }
    await file.writeAsString('${lines.join('\n')}\n', flush: true);
  }
}
