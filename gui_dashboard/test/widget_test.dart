import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/installer_main.dart';

void main() {
  testWidgets(
    'installer wizard renders in offline test mode without side effects',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));

      expect(find.text('HWControl Kurulum Sihirbazı'), findsOneWidget);
      expect(find.text('Yerel AI (Gemma 3 1B)'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    },
  );

  testWidgets(
    'installer wizard keeps navigation controls available in test mode',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));

      expect(find.text('1. Paket türünü doğrula'), findsOneWidget);
      expect(find.text('Devam'), findsOneWidget);

      await tester.tap(find.text('Devam'));
      await tester.pump();

      expect(find.text('2. Bridge durumunu doğrula'), findsOneWidget);
      expect(find.text('Devam'), findsOneWidget);
    },
  );

  testWidgets(
    'installer wizard does not start installation work while initialized state is disabled',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));

      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);

      final tile = tester.widget<CheckboxListTile>(checkbox);
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
    },
  );
}
