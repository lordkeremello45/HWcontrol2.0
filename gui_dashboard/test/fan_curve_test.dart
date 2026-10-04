import 'package:flutter_test/flutter_test.dart';
import '../lib/fan_curve.dart';

void main() {
  test('fan curve interpolates between points', () {
    const curve = FanCurve(<FanCurvePoint>[
      FanCurvePoint(40, 20),
      FanCurvePoint(80, 80),
    ]);
    expect(curve.evaluate(40), 20);
    expect(curve.evaluate(60), 50);
    expect(curve.evaluate(80), 80);
    expect(curve.evaluate(100), 80);
  });

  test('invalid persisted curve falls back to balanced', () {
    final curve = FanCurve.fromJson(<dynamic>[{'temperature': 70}]);
    expect(curve.points.length, FanCurve.balanced.points.length);
  });
}
