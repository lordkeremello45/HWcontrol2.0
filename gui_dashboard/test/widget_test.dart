import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/installer_main.dart';

void main() {
  testWidgets('installer wizard renders without starting bridge network or model download', (tester) async {
    await tester.pumpWidget(const InstallerApp(initialize: false));
    expect(find.text('HWControl Kurulum Sihirbazı'), findsOneWidget);
    expect(find.text('Yerel AI (Gemma 3 1B)'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
}
