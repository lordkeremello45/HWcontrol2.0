import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hwcontrol_dashboard/setup_wizard.dart';

void main() {
  testWidgets('requires safety acknowledgement before continuing', (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
      home: HWControlSetupWizard(
        onComplete: (value) => result = value,
        onCancel: () {},
      ),
    ));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Hardware-control safety'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    await tester.tap(find.text(
      'I understand that hardware control is enabled only when the backend confirms support.',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review and finish'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(result?['setupWizardCompleted'], isTrue);
    expect(result?['fanSafetyAcknowledged'], isTrue);
  });

  testWidgets('profile selection is captured without claiming hardware support', (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
      home: HWControlSetupWizard(
        onComplete: (value) => result = value,
        onCancel: () {},
        translations: const <String, String>{
          'wizardTitle': 'HWcontrol Setup',
          'wizardNext': 'Next',
        },
      ),
    ));

    await tester.tap(find.text('Performance').first);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start HWcontrol with the system'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(
      'I understand that hardware control is enabled only when the backend confirms support.',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(result?['preferredProfile'], 'performance');
    expect(result?['startWithSystem'], isTrue);
    expect(result?['automaticFanControlRequested'], isFalse);
    expect(result?['securityScannerRequested'], isFalse);
  });
}


  testWidgets('optional security scanner choice is saved only when opted in', (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
      home: HWControlSetupWizard(
        onComplete: (value) => result = value,
        onCancel: () {},
      ),
    ));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request optional HWcontrol Security scanning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(
      'I understand that hardware control is enabled only when the backend confirms support.',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(result?['securityScannerRequested'], isTrue);
  });
