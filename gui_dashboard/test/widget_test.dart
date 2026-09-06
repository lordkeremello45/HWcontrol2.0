import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/main.dart';

void main() {
  testWidgets('dashboard starts without rendering errors', (tester) async {
    await tester.pumpWidget(const HWControlApp());
    expect(find.byType(HWControlApp), findsOneWidget);
  });
}
