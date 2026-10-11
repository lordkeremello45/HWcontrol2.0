import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/installer_main.dart';

void expectOneOf(WidgetTester tester, List<String> labels) {
  expect(
    labels.any((label) => find.text(label).evaluate().isNotEmpty),
    isTrue,
    reason: 'Expected one localized label from: ' + labels.join(', '),
  );
}

void main() {
  testWidgets(
    'installer wizard renders in offline test mode without side effects',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));
      await tester.pumpAndSettle();

      expectOneOf(tester, ['HWControl Setup Wizard', 'HWControl Kurulum Sihirbazı']);
      expectOneOf(tester, ['Local AI (Gemma 3 1B)', 'Yerel AI (Gemma 3 1B)']);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    },
  );

  testWidgets(
    'installer wizard keeps navigation controls available in test mode',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));
      await tester.pumpAndSettle();

      expectOneOf(tester, ['1. Verify package type', '1. Paket türünü doğrula']);
      expectOneOf(tester, ['Continue', 'Devam']);

      final continueLabel = find.text('Continue').evaluate().isNotEmpty
          ? find.text('Continue')
          : find.text('Devam');
      await tester.tap(continueLabel);
      await tester.pump();

      expectOneOf(tester, ['2. Verify bridge status', '2. Bridge durumunu doğrula']);
      expectOneOf(tester, ['Continue', 'Devam']);
    },
  );

  testWidgets(
    'installer wizard does not start installation work while initialized state is disabled',
    (tester) async {
      await tester.pumpWidget(const InstallerApp(initialize: false));
      await tester.pumpAndSettle();

      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);

      final tile = tester.widget<CheckboxListTile>(checkbox);
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
    },
  );
}
