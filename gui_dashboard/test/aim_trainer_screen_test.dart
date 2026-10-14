import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/aim_trainer_screen.dart';
import 'package:hwcontrol_dashboard/user_data_store.dart';

void main() {
  late Directory temporaryDirectory;
  late HWControlUserDataStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('hwcontrol-aim-test-');
    store = HWControlUserDataStore(
      supportDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
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
    expect(find.text('1'), findsOneWidget);

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('persists bounded session history', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: HWAimTrainerScreen(
        store: store,
        sessionSeconds: 5,
        random: () => math.Random(1),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aim-start')));
    await tester.pump();

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final preferences = await store.readUiPreferences();
      expect(preferences['aimTrainerHistory'], isA<List>());
      expect((preferences['aimTrainerHistory'] as List), hasLength(1));
    });
    expect(find.text('Session complete'), findsOneWidget);
  });
}
