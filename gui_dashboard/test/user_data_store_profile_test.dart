import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/profile_document.dart';
import 'package:hwcontrol_dashboard/user_data_store.dart';

void main() {
  late Directory temporaryDirectory;
  late HWControlUserDataStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'hwcontrol-profile-store-test-',
    );
    store = HWControlUserDataStore(
      supportDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  HWControlProfile makeProfile({
    String id = 'balanced-1',
    String name = 'Balanced',
  }) =>
      HWControlProfile(
        id: id,
        name: name,
        mode: 'balanced',
        createdAt: '2026-10-01T10:00:00Z',
        updatedAt: '2026-10-01T10:00:00Z',
        fanCurve: const <HWControlFanPoint>[
          HWControlFanPoint(temperatureCelsius: 35, fanPercent: 25),
          HWControlFanPoint(temperatureCelsius: 70, fanPercent: 60),
        ],
      );

  test('writes and reads the typed profile collection', () async {
    final expected = HWControlProfileCollection(<HWControlProfile>[
      makeProfile(),
      makeProfile(id: 'quiet-1', name: 'Quiet'),
    ]);

    await store.writeValidatedProfiles(expected);
    final actual = await store.readValidatedProfiles();

    expect(actual.profiles.length, 2);
    expect(actual.profiles.map((p) => p.id), ['balanced-1', 'quiet-1']);
    expect(actual.profiles.last.name, 'Quiet');
  });

  test('starts with an empty typed collection when no file exists', () async {
    expect((await store.readValidatedProfiles()).profiles, isEmpty);
  });

  test('keeps legacy profiles separate and unchanged', () async {
    const legacy = <String, dynamic>{
      'Performance': <String, double>{'fan': 88.0, 'ai': 95.0},
    };
    await store.writeProfiles(legacy);
    await store.writeValidatedProfiles(
      HWControlProfileCollection(<HWControlProfile>[makeProfile()]),
    );

    expect(await store.readProfiles(), legacy);
    expect((await store.readValidatedProfiles()).profiles.single.id, 'balanced-1');
  });

  test('does not silently discard an unsupported typed document', () async {
    final file = await store.configFile('profiles.v1.json');
    const source = '{"schemaVersion":999,"profiles":[]}';
    await file.writeAsString(source);

    await expectLater(
      store.readValidatedProfiles(),
      throwsFormatException,
    );
    expect(await file.readAsString(), source);
  });

  test('does not treat malformed JSON as an empty profile collection', () async {
    final file = await store.configFile('profiles.v1.json');
    const source = '{"schemaVersion":1,"profiles":';
    await file.writeAsString(source);

    await expectLater(
      store.readValidatedProfiles(),
      throwsFormatException,
    );
    expect(await file.readAsString(), source);
  });
}
