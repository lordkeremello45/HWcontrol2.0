import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/aim_trainer_screen.dart';
import 'package:hwcontrol_dashboard/user_data_store.dart';

class _MemoryUserDataStore extends HWControlUserDataStore {
  Map<String, dynamic> _preferences = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> readUiPreferences() async =>
      Map<String, dynamic>.from(_preferences);

  @override
  Future<void> writeUiPreferences(Map<String, dynamic> values) async {
    _preferences = Map<String, dynamic>.from(values);
  }
}

void main() {
  late _MemoryUserDataStore store;

  setUp(() {
    store = _MemoryUserDataStore();
  });

  testWidgets('shows offline trainer and starts a session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: HWAimTrainerScreen(
        store: store,
        sessionSeconds: 10,
        random: () => math.Random(7),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aim Trainer'), findsOneWidget);
    expect(find.textContaining('does not control games or hardware'), findsOneWidget);
    expect(find.byKey(const ValueKey('aim-target')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('aim-start')));
    await tester.pump();

    expect(find.byKey(const ValueKey('aim-target')), findsOneWidget);
    expect(find.text('10s'), findsOneWidget);
  });

  testWidgets('records hits and misses without hardware commands', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: HWAimTrainerScreen(
        store: store,
        sessionSeconds: 10,
        random: () => math.Random(9),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aim-start')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('aim-target')));
    await tester.pump();
    expect(find.text('Hits: 1'), findsOneWidget);
    expect(find.text('Misses: 0'), findsOneWidget);
  });

  testWidgets('persists bounded session history', (tester) async {
    final saved = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: HWAimTrainerScreen(
        store: store,
        sessionSeconds: 5,
        random: () => math.Random(1),
        onSessionSaved: () => saved.complete(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aim-start')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saved.future.timeout(const Duration(seconds: 5));
      final preferences = await store.readUiPreferences();
      expect(preferences['aimTrainerHistory'], isA<List>());
      expect((preferences['aimTrainerHistory'] as List), isNotEmpty);
      expect((preferences['aimTrainerHistory'] as List).last['durationSeconds'], 5);
    });
    expect(find.text('Session complete'), findsOneWidget);
  });
}
