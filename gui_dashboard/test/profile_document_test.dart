import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/profile_document.dart';

const created = '2026-10-01T10:00:00Z';
const updated = '2026-10-01T10:00:00Z';

HWControlProfile profile({
  String id = 'profile-1',
  String name = 'Balanced',
  String mode = 'balanced',
}) =>
    HWControlProfile(
      id: id,
      name: name,
      mode: mode,
      createdAt: created,
      updatedAt: updated,
      fanCurve: const <HWControlFanPoint>[
        HWControlFanPoint(temperatureCelsius: 35, fanPercent: 25),
        HWControlFanPoint(temperatureCelsius: 70, fanPercent: 60),
        HWControlFanPoint(temperatureCelsius: 90, fanPercent: 90),
      ],
    );

void main() {
  group('HWControlProfile', () {
    test('round-trips a versioned data-only profile', () {
      final original = profile();
      final restored = HWControlProfile.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.mode, original.mode);
      expect(restored.fanCurve.length, 3);
      expect(restored.gameModeEnabled, isFalse);
    });

    test('rejects unknown fields and unsupported schema versions', () {
      expect(
        () => HWControlProfile.fromJson(<String, Object?>{
          ...profile().toJson(),
          'shellCommand': 'not allowed',
        }),
        throwsFormatException,
      );
      expect(
        () => HWControlProfile.fromJson(<String, Object?>{
          ...profile().toJson(),
          'schemaVersion': 99,
        }),
        throwsFormatException,
      );
    });

    test('rejects invalid IDs, modes, timestamps and names', () {
      expect(
        () => profile(id: '../arbitrary-path'),
        throwsFormatException,
      );
      expect(() => profile(name: '   '), throwsFormatException);
      expect(() => profile(mode: 'overclock-everything'), throwsFormatException);
      expect(
        () => HWControlProfile(
          id: 'profile-2',
          name: 'Bad timestamps',
          mode: 'custom',
          createdAt: updated,
          updatedAt: '2026-09-30T10:00:00Z',
          fanCurve: profile().fanCurve,
        ),
        throwsFormatException,
      );
    });

    test('rejects decreasing or duplicate temperature breakpoints', () {
      expect(
        () => HWControlProfile(
          id: 'profile-2',
          name: 'Non-monotonic',
          mode: 'custom',
          createdAt: created,
          updatedAt: updated,
          fanCurve: const <HWControlFanPoint>[
            HWControlFanPoint(temperatureCelsius: 70, fanPercent: 60),
            HWControlFanPoint(temperatureCelsius: 60, fanPercent: 70),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => HWControlProfile(
          id: 'profile-2',
          name: 'Duplicate point',
          mode: 'custom',
          createdAt: created,
          updatedAt: updated,
          fanCurve: const <HWControlFanPoint>[
            HWControlFanPoint(temperatureCelsius: 50, fanPercent: 40),
            HWControlFanPoint(temperatureCelsius: 50, fanPercent: 50),
          ],
        ),
        throwsFormatException,
      );
    });

    test('does not permit fan demand to fall as temperature rises', () {
      expect(
        () => HWControlProfile(
          id: 'profile-2',
          name: 'Unsafe curve',
          mode: 'custom',
          createdAt: created,
          updatedAt: updated,
          fanCurve: const <HWControlFanPoint>[
            HWControlFanPoint(temperatureCelsius: 30, fanPercent: 70),
            HWControlFanPoint(temperatureCelsius: 80, fanPercent: 50),
          ],
        ),
        throwsFormatException,
      );
    });

    test('rename and duplicate preserve data but require explicit IDs/times', () {
      final original = profile();
      final renamed = original.rename(newName: 'Gaming', updatedAt: '2026-10-02T10:00:00Z');
      final duplicate = original.duplicate(
        newId: 'profile-2',
        newName: 'Gaming copy',
        createdAt: '2026-10-02T10:00:00Z',
        updatedAt: '2026-10-02T10:00:00Z',
      );
      expect(renamed.id, original.id);
      expect(renamed.name, 'Gaming');
      expect(duplicate.id, 'profile-2');
      expect(duplicate.fanCurve.length, original.fanCurve.length);
    });
  });

  group('HWControlProfileCollection', () {
    test('round-trips JSON and supports add, replace and remove', () {
      final collection = HWControlProfileCollection(<HWControlProfile>[profile()]);
      final decoded = HWControlProfileCollection.decode(collection.encode());
      expect(decoded.profiles.length, 1);
      expect(decoded.add(profile(id: 'profile-2', name: 'Quiet')).profiles.length, 2);
      expect(
        decoded.replace(profile(name: 'Performance', mode: 'performance')).profiles.single.name,
        'Performance',
      );
      expect(decoded.remove('profile-1').profiles, isEmpty);
    });

    test('rejects duplicate IDs and case-insensitive duplicate names', () {
      expect(
        () => HWControlProfileCollection(<HWControlProfile>[
          profile(),
          profile(name: 'Quiet'),
        ]),
        throwsFormatException,
      );
      expect(
        () => HWControlProfileCollection(<HWControlProfile>[
          profile(),
          profile(id: 'profile-2', name: 'balanced'),
        ]),
        throwsFormatException,
      );
    });

    test('rejects malformed documents and unknown root fields', () {
      expect(
        () => HWControlProfileCollection.decode('not json'),
        throwsFormatException,
      );
      expect(
        () => HWControlProfileCollection.decode(jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'profiles': <Object?>[],
          'executable': 'evil',
        })),
        throwsFormatException,
      );
    });

    test('enforces the document size limit before parsing', () {
      expect(
        () => HWControlProfileCollection.decode(
          ' ' * (HWControlProfile.maxDocumentBytes + 1),
        ),
        throwsFormatException,
      );
    });
  });
}
