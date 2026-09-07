import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/installer_main.dart';

void main() {
  testWidgets('installer wizard renders without starting bridge network', (tester) async {
    await tester.pumpWidget(const InstallerApp());
    expect(find.text('HWControl Kurulum Sihirbazı'), findsOneWidget);
  });
}
