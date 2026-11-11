import 'package:flutter_test/flutter_test.dart';
import 'package:hwcontrol_dashboard/automation_rules.dart';

void main() {
  test('automation selects highest matched threshold', () {
    const engine = HardwareAutomationEngine(<HardwareAutomationRule>[
      HardwareAutomationRule(
        name: 'warm',
        sensor: 'cpuTemperature',
        threshold: 70,
        fanPercent: 50,
      ),
      HardwareAutomationRule(
        name: 'hot',
        sensor: 'cpuTemperature',
        threshold: 85,
        fanPercent: 90,
      ),
    ]);
    expect(engine.evaluate(<String, dynamic>{'cpuTemperature': 90}), 90);
  });

  test('disabled rule is ignored', () {
    const engine = HardwareAutomationEngine(<HardwareAutomationRule>[
      HardwareAutomationRule(
        name: 'disabled',
        sensor: 'gpuTemperature',
        threshold: 70,
        fanPercent: 90,
        enabled: false,
      ),
    ]);
    expect(engine.evaluate(<String, dynamic>{'gpuTemperature': 90}), isNull);
  });

  test('legacy automation fan targets are migrated to the bridge floor', () {
    final rule = HardwareAutomationRule.fromJson(<String, dynamic>{
      'name': 'legacy rule',
      'sensor': 'cpuTemperature',
      'threshold': 80,
      'fan': 0,
      'enabled': true,
    });

    expect(rule, isNotNull);
    expect(rule!.fanPercent, 20);
    expect(rule.toJson()['fan'], 20);
  });

  test('engine never returns a fan target below the bridge floor', () {
    const engine = HardwareAutomationEngine(<HardwareAutomationRule>[
      HardwareAutomationRule(
        name: 'legacy in-memory rule',
        sensor: 'cpuTemperature',
        threshold: 80,
        fanPercent: 1,
      ),
    ]);

    expect(engine.evaluate(<String, dynamic>{'cpuTemperature': 90}), 20);
  });
}
