import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/fan_curve.dart';

void main() {
  test('fan curve interpolates between points', () {
    const curve = FanCurve([
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 80),
    ]);
    expect(curve.evaluate(60), 50);
  });

  test('controller smooths, rate-limits and clamps fan target', () {
    final controller = FanCurveController(
      minimumChangePercent: 2,
      minimumCommandInterval: const Duration(seconds: 2),
      smoothingSamples: 3,
    );
    final t0 = DateTime(2026, 1, 1);
    const curve = FanCurve([
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 100),
    ]);
    expect(controller.nextTarget(
      curve: curve,
      temperature: 40,
      now: t0,
      sensorValid: true,
      hardwareControlSupported: true,
    ), 20);
    expect(controller.nextTarget(
      curve: curve,
      temperature: 60,
      now: t0.add(const Duration(seconds: 1)),
      sensorValid: true,
      hardwareControlSupported: true,
    ), isNull);
    expect(controller.nextTarget(
      curve: curve,
      temperature: 60,
      now: t0.add(const Duration(seconds: 2)),
      sensorValid: true,
      hardwareControlSupported: true,
    ), isNotNull);
  });

  test('invalid sensor fails closed', () {
    final controller = FanCurveController();
    const curve = FanCurve([FanCurvePoint(40, 20), FanCurvePoint(80, 80)]);
    expect(controller.nextTarget(
      curve: curve,
      temperature: double.nan,
      now: DateTime(2026),
      sensorValid: false,
      hardwareControlSupported: true,
    ), isNull);
  });
}
