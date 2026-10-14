import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/fan_channels.dart';
import 'package:hwcontrol_dashboard/fan_curve.dart';

void main() {
  test('fan telemetry rejects malformed channel IDs as controllable', () {
    final channel = FanChannelTelemetry.fromJson(<String, dynamic>{
      'id': '/sys/class/hwmon/hwmon0/pwm1',
      'name': 'Unsafe target',
      'backend': 'linux-hwmon',
      'supported': true,
      'fanRpm': 1200,
      'rpmAvailable': true,
      'fanPercent': 50,
      'percentAvailable': true,
    });

    expect(channel.id, isEmpty);
    expect(channel.supported, isFalse);
    expect(channel.rpmAvailable, isTrue);
  });

  test('fan profiles preserve independent sensor and manual settings', () {
    final original = FanChannelProfile(
      curve: const FanCurve(<FanCurvePoint>[
        FanCurvePoint(40, 25),
        FanCurvePoint(70, 60),
        FanCurvePoint(90, 100),
      ]),
      sensorSource: 'gpuTemperature',
      automaticEnabled: false,
      manualPercent: 72,
    );

    final restored = FanChannelProfile.fromJson(original.toJson());

    expect(restored.sensorSource, 'gpuTemperature');
    expect(restored.automaticEnabled, isFalse);
    expect(restored.manualPercent, 72);
    expect(restored.curve.evaluate(90), 100);
  });

  test('invalid fan profile values fall back to safe defaults', () {
    final restored = FanChannelProfile.fromJson(<String, dynamic>{
      'sensor': 'unknownSensor',
      'automaticEnabled': true,
      'manualPercent': 0,
      'curve': <Map<String, double>>[
        <String, double>{'temperature': 40, 'fan': 0},
        <String, double>{'temperature': 80, 'fan': 10},
      ],
    });

    expect(restored.sensorSource, 'hottest');
    expect(restored.manualPercent, 20);
    expect(restored.curve.evaluate(40), 20);
    expect(restored.curve.evaluate(80), 20);
  });

  test('sensor selector fails closed when the chosen source is missing', () {
    expect(
      selectFanControlTemperature(
        sensorSource: 'cpuTemperature',
        cpuTemperature: double.nan,
        gpuTemperature: 74,
      ),
      isNull,
    );
    expect(
      selectFanControlTemperature(
        sensorSource: 'gpuTemperature',
        cpuTemperature: 55,
        gpuTemperature: double.infinity,
      ),
      isNull,
    );
  });

  test('hottest sensor selector tolerates one missing sensor', () {
    expect(
      selectFanControlTemperature(
        sensorSource: 'hottest',
        cpuTemperature: 55,
        gpuTemperature: double.nan,
      ),
      55,
    );
    expect(
      selectFanControlTemperature(
        sensorSource: 'hottest',
        cpuTemperature: 55,
        gpuTemperature: 80,
      ),
      80,
    );
  });
}
