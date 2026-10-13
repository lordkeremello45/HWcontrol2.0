import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/game_profile.dart';

void main() {
  group('normalizeGameProcessName', () {
    test('normalizes case, whitespace, and Windows paths', () {
      expect(
        normalizeGameProcessName(r'  C:\Games\MY-GAME.EXE  '),
        'my-game.exe',
      );
    });

    test('returns an empty name for empty input', () {
      expect(normalizeGameProcessName('  '), isEmpty);
    });
  });

  group('assignedGameProfileName', () {
    test('matches executable names case-insensitively', () {
      expect(
        assignedGameProfileName(
          processName: 'C:\\Games\\MY-GAME.EXE',
          assignments: const {'my-game.exe': 'Performance'},
        ),
        'Performance',
      );
    });

    test('does not assign a profile to an empty process name', () {
      expect(
        assignedGameProfileName(
          processName: '',
          assignments: const {'game.exe': 'Performance'},
        ),
        isNull,
      );
    });

    test('ignores blank profile assignments', () {
      expect(
        assignedGameProfileName(
          processName: 'game.exe',
          assignments: const {'game.exe': '  '},
        ),
        isNull,
      );
    });
  });

  group('resolveGameProfileFanTarget', () {
    const assignments = {'game.exe': 'Performance'};
    const profiles = {
      'Performance': {'fan': 88.0, 'ai': 95.0},
    };

    test('uses the assigned profile fan target', () {
      expect(
        resolveGameProfileFanTarget(
          processName: 'GAME.EXE',
          assignments: assignments,
          profiles: profiles,
        ),
        88,
      );
    });

    test('uses the safe default when no profile is assigned', () {
      expect(
        resolveGameProfileFanTarget(
          processName: 'other.exe',
          assignments: assignments,
          profiles: profiles,
        ),
        75,
      );
    });

    test('clamps stored fan targets to the supported range', () {
      expect(
        resolveGameProfileFanTarget(
          processName: 'game.exe',
          assignments: assignments,
          profiles: const {'Performance': {'fan': 120.0}},
        ),
        100,
      );
      expect(
        resolveGameProfileFanTarget(
          processName: 'game.exe',
          assignments: assignments,
          profiles: const {'Performance': {'fan': -5.0}},
        ),
        1,
      );
    });

    test('falls back when a saved target is not finite', () {
      expect(
        resolveGameProfileFanTarget(
          processName: 'game.exe',
          assignments: assignments,
          profiles: {'Performance': {'fan': double.nan}},
        ),
        75,
      );
    });
  });
}
