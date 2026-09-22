import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistent per-user application data.
///
/// User-controlled state is deliberately kept separate from application
/// binaries and release metadata. Each logical data set gets its own file so
/// corruption or migration of one area does not invalidate the others.
class HWControlUserDataStore {
  static const int currentSchema = 1;

  Future<Directory> get directory async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}HWControl',
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> file(String name) async {
    final dir = await directory;
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> readJsonObject(String name) async {
    final target = await file(name);
    if (!await target.exists()) return null;

    try {
      final decoded = jsonDecode(await target.readAsString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJsonObject(
    String name,
    Map<String, dynamic> value,
  ) async {
    final target = await file(name);
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
}
