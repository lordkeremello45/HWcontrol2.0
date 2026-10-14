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

  test('fan curve normalization never lowers fan demand as temperature rises', () {
    const curve = FanCurve([
      FanCurvePoint(40, 60),
      FanCurvePoint(60, 35),
      FanCurvePoint(80, 75),
    ]);

    expect(curve.evaluate(40), 60);
    expect(curve.evaluate(50), 60);
    expect(curve.evaluate(60), 60);
    expect(curve.evaluate(70), 67.5);
    expect(curve.evaluate(80), 75);

    final saved = curve.toJson();
    expect((saved[0]['fan']!), lessThanOrEqualTo(saved[1]['fan']!));
    expect((saved[1]['fan']!), lessThanOrEqualTo(saved[2]['fan']!));
  });

  test('duplicate temperature breakpoints collapse to the strongest target', () {
    const curve = FanCurve([
      FanCurvePoint(40, 25),
      FanCurvePoint(60, 45),
      FanCurvePoint(60, 80),
      FanCurvePoint(80, 70),
    ]);

    final normalized = curve.safetyNormalizedPoints;
    expect(normalized.map((point) => point.temperature).toSet().length,
        normalized.length);
    expect(curve.evaluate(60), 80);
    expect(curve.evaluate(70), 80);
    expect(curve.evaluate(80), 80);
  });

  test('fan curves enforce a nonzero cooling floor', () {
    const curve = FanCurve([
      FanCurvePoint(40, 0),
      FanCurvePoint(80, 10),
    ]);

    expect(curve.evaluate(40), 20);
    expect(curve.evaluate(80), 20);
    expect(FanCurve.fromJson(curve.toJson()).evaluate(60), 20);
  });

  test('automation rules cannot reduce a stronger curve target', () {
    expect(
      resolveAutomaticFanTarget(
        curveTarget: 90,
        ruleTarget: 70,
        currentFanPercent: 85,
      ),
      90,
    );
    expect(
      resolveAutomaticFanTarget(
        curveTarget: 70,
        ruleTarget: 90,
        currentFanPercent: 70,
      ),
      90,
    );
  });

  test('automation rules cannot lower fan speed while curve is rate-limited', () {
    expect(
      resolveAutomaticFanTarget(
        curveTarget: null,
        ruleTarget: 70,
        currentFanPercent: 85,
      ),
      isNull,
    );
    expect(
      resolveAutomaticFanTarget(
        curveTarget: null,
        ruleTarget: 90,
        currentFanPercent: 85,
      ),
      90,
    );
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

  test('controller hysteresis suppresses small temperature oscillations', () {
    final controller = FanCurveController(
      smoothingSamples: 1,
      hysteresisCelsius: 2,
      minimumChangePercent: 1,
      minimumCommandInterval: Duration.zero,
    );
    const curve = FanCurve([
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 100),
    ]);
    final start = DateTime(2026, 1, 1);
    double? target(double temperature, int seconds) => controller.nextTarget(
      curve: curve,
      temperature: temperature,
      now: start.add(Duration(seconds: seconds)),
      sensorValid: true,
      hardwareControlSupported: true,
    );

    expect(target(50, 0), isNotNull);
    expect(target(51, 1), isNull);
    expect(target(51.8, 2), isNull);
    expect(target(53, 3), isNotNull);
  });

  test('controller refuses targets when hardware control is unavailable', () {
    final controller = FanCurveController();
    const curve = FanCurve([
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 100),
    ]);
    expect(controller.nextTarget(
      curve: curve,
      temperature: 75,
      now: DateTime(2026, 1, 1),
      sensorValid: true,
      hardwareControlSupported: false,
    ), isNull);
  });

  test('invalid telemetry resets previous hysteresis state', () {
    final controller = FanCurveController(smoothingSamples: 1);
    const curve = FanCurve([
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 100),
    ]);
    final start = DateTime(2026, 1, 1);
    expect(controller.nextTarget(
      curve: curve, temperature: 50, now: start,
      sensorValid: true, hardwareControlSupported: true,
    ), isNotNull);
    expect(controller.nextTarget(
      curve: curve, temperature: double.nan, now: start.add(const Duration(seconds: 1)),
      sensorValid: false, hardwareControlSupported: true,
    ), isNull);
    expect(controller.nextTarget(
      curve: curve, temperature: 75, now: start.add(const Duration(seconds: 2)),
      sensorValid: true, hardwareControlSupported: true,
    ), isNotNull);
  });
}
