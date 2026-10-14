import 'dart:convert';

/// Versioned, data-only user profile format.
///
/// This model stores requests/preferences; it does not apply hardware changes.
/// The bridge and a verified platform adapter remain authoritative for writes.
class HWControlProfile {
  HWControlProfile({
    required this.id,
    required this.name,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    required List<HWControlFanPoint> fanCurve,
    this.gameModeEnabled = false,
  }) : fanCurve = List<HWControlFanPoint>.unmodifiable(fanCurve) {
    _validate();
  }

  static const int schemaVersion = 1;
  static const int maxNameLength = 64;
  static const int maxProfiles = 100;
  static const int maxDocumentBytes = 1024 * 1024;
  static const int maxFanCurvePoints = 16;

  static const Set<String> modes = <String>{
    'quiet',
    'balanced',
    'performance',
    'custom',
  };

  final String id;
  final String name;
  final String mode;
  final String createdAt;
  final String updatedAt;
  final List<HWControlFanPoint> fanCurve;
  final bool gameModeEnabled;

  void _validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw const FormatException('Profile ID is invalid.');
    }
    if (name.trim().isEmpty || name.trim().length > maxNameLength) {
      throw const FormatException('Profile name must contain 1–64 characters.');
    }
    if (!modes.contains(mode)) {
      throw const FormatException('Profile mode is not supported.');
    }
    final created = DateTime.tryParse(createdAt);
    final updated = DateTime.tryParse(updatedAt);
    if (created == null || updated == null || updated.isBefore(created)) {
      throw const FormatException('Profile timestamps are invalid.');
    }
    if (fanCurve.length < 2 || fanCurve.length > maxFanCurvePoints) {
      throw const FormatException('Fan curve must contain 2–16 points.');
    }
    for (var i = 1; i < fanCurve.length; i++) {
      if (fanCurve[i].temperatureCelsius <=
          fanCurve[i - 1].temperatureCelsius) {
        throw const FormatException(
          'Fan curve temperatures must be strictly increasing.',
        );
      }
      if (fanCurve[i].fanPercent < fanCurve[i - 1].fanPercent) {
        throw const FormatException(
          'Fan demand must not decrease as temperature rises.',
        );
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name.trim(),
        'mode': mode,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'gameModeEnabled': gameModeEnabled,
        'fanCurve': fanCurve.map((point) => point.toJson()).toList(),
      };

  factory HWControlProfile.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      'schemaVersion',
      'id',
      'name',
      'mode',
      'createdAt',
      'updatedAt',
      'gameModeEnabled',
      'fanCurve',
    };
    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        !json.keys.toSet().containsAll(expectedKeys)) {
      throw const FormatException('Profile contains unknown or missing fields.');
    }
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Profile schema version is not supported.');
    }
    final curve = json['fanCurve'];
    if (curve is! List) {
      throw const FormatException('Fan curve must be a list.');
    }
    final points = curve.map((value) {
      if (value is! Map) {
        throw const FormatException('Fan curve point must be an object.');
      }
      return HWControlFanPoint.fromJson(Map<String, Object?>.from(value));
    }).toList(growable: false);
    final id = json['id'];
    final name = json['name'];
    final mode = json['mode'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final gameModeEnabled = json['gameModeEnabled'];
    if (id is! String ||
        name is! String ||
        mode is! String ||
        createdAt is! String ||
        updatedAt is! String ||
        gameModeEnabled is! bool) {
      throw const FormatException('Profile field types are invalid.');
    }
    return HWControlProfile(
      id: id,
      name: name,
      mode: mode,
      createdAt: createdAt,
      updatedAt: updatedAt,
      gameModeEnabled: gameModeEnabled,
      fanCurve: points,
    );
  }

  HWControlProfile rename({
    required String newName,
    required String updatedAt,
  }) =>
      HWControlProfile(
        id: id,
        name: newName,
        mode: mode,
        createdAt: createdAt,
        updatedAt: updatedAt,
        gameModeEnabled: gameModeEnabled,
        fanCurve: fanCurve,
      );

  HWControlProfile duplicate({
    required String newId,
    required String newName,
    required String createdAt,
    required String updatedAt,
  }) =>
      HWControlProfile(
        id: newId,
        name: newName,
        mode: mode,
        createdAt: createdAt,
        updatedAt: updatedAt,
        gameModeEnabled: gameModeEnabled,
        fanCurve: fanCurve,
      );
}

class HWControlFanPoint {
  const HWControlFanPoint({
    required this.temperatureCelsius,
    required this.fanPercent,
  });

  final int temperatureCelsius;
  final int fanPercent;

  Map<String, int> toJson() => <String, int>{
        'temperatureCelsius': temperatureCelsius,
        'fanPercent': fanPercent,
      };

  factory HWControlFanPoint.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{'temperatureCelsius', 'fanPercent'};
    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        !json.keys.toSet().containsAll(expectedKeys)) {
      throw const FormatException('Fan curve point contains invalid fields.');
    }
    final temperature = json['temperatureCelsius'];
    final percent = json['fanPercent'];
    if (temperature is! int || percent is! int) {
      throw const FormatException('Fan curve values must be integers.');
    }
    if (temperature < 0 || temperature > 120 || percent < 1 || percent > 100) {
      throw const FormatException('Fan curve values are outside safe bounds.');
    }
    return HWControlFanPoint(
      temperatureCelsius: temperature,
      fanPercent: percent,
    );
  }
}

/// A bounded collection with unique IDs and case-insensitive unique names.
class HWControlProfileCollection {
  HWControlProfileCollection(Iterable<HWControlProfile> profiles)
      : profiles = List<HWControlProfile>.unmodifiable(profiles) {
    _validate();
  }

  final List<HWControlProfile> profiles;

  void _validate() {
    if (profiles.length > HWControlProfile.maxProfiles) {
      throw const FormatException('A maximum of 100 profiles is allowed.');
    }
    final ids = <String>{};
    final names = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) {
        throw const FormatException('Profile IDs must be unique.');
      }
      if (!names.add(profile.name.trim().toLowerCase())) {
        throw const FormatException('Profile names must be unique.');
      }
    }
  }

  String encode() {
    final encoded = const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'schemaVersion': HWControlProfile.schemaVersion,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
    });
    if (utf8.encode(encoded).length > HWControlProfile.maxDocumentBytes) {
      throw const FormatException('Profile document exceeds the size limit.');
    }
    return encoded;
  }

  factory HWControlProfileCollection.decode(String source) {
    if (utf8.encode(source).length > HWControlProfile.maxDocumentBytes) {
      throw const FormatException('Profile document exceeds the size limit.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Profile document must be an object.');
    }
    final root = Map<String, Object?>.from(decoded);
    if (root.keys.toSet().difference(const <String>{'schemaVersion', 'profiles'}).isNotEmpty ||
        !root.keys.toSet().containsAll(const <String>{'schemaVersion', 'profiles'}) ||
        root['schemaVersion'] != HWControlProfile.schemaVersion ||
        root['profiles'] is! List) {
      throw const FormatException('Profile document schema is invalid.');
    }
    final values = root['profiles'] as List;
    if (values.length > HWControlProfile.maxProfiles) {
      throw const FormatException('A maximum of 100 profiles is allowed.');
    }
    final profiles = values.map((value) {
      if (value is! Map) {
        throw const FormatException('Profile entry must be an object.');
      }
      return HWControlProfile.fromJson(Map<String, Object?>.from(value));
    });
    return HWControlProfileCollection(profiles);
  }

  HWControlProfileCollection add(HWControlProfile profile) =>
      HWControlProfileCollection(<HWControlProfile>[...profiles, profile]);

  HWControlProfileCollection replace(HWControlProfile profile) {
    final index = profiles.indexWhere((existing) => existing.id == profile.id);
    if (index < 0) throw const FormatException('Profile to replace was not found.');
    final next = profiles.toList();
    next[index] = profile;
    return HWControlProfileCollection(next);
  }

  HWControlProfileCollection remove(String id) {
    if (!profiles.any((profile) => profile.id == id)) {
      throw const FormatException('Profile to remove was not found.');
    }
    return HWControlProfileCollection(
      profiles.where((profile) => profile.id != id),
    );
  }
}
