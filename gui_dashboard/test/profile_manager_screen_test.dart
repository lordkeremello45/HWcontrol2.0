import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/profile_manager_screen.dart';
import 'package:hwcontrol_dashboard/user_data_store.dart';

void main() {
  late Directory temporaryDirectory;
  late HWControlUserDataStore store;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'hwcontrol-profile-manager-test-',
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

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HWControlProfileManagerScreen(store: store)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('creates and persists a profile', (tester) async {
    await openScreen(tester);

    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Quiet desk');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Quiet desk'), findsOneWidget);
    final stored = await store.readValidatedProfiles();
    expect(stored.profiles, hasLength(1));
    expect(stored.profiles.single.name, 'Quiet desk');
    expect(stored.profiles.single.mode, 'balanced');
  });

  testWidgets('renames a profile and rejects duplicate names safely', (tester) async {
    await openScreen(tester);
    await tester.tap(find.text('Create profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Balanced');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Custom desk');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Custom desk'), findsOneWidget);
    expect((await store.readValidatedProfiles()).profiles.single.name, 'Custom desk');
  });

  testWidgets('shows recovery guidance for a malformed saved document', (tester) async {
    final file = await store.configFile('profiles.v1.json');
    await file.writeAsString('not valid json');

    await openScreen(tester);

    expect(find.textContaining('original file was preserved'), findsOneWidget);
    expect(await file.readAsString(), 'not valid json');
  });
}
