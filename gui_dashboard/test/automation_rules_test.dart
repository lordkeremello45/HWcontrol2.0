import 'package:flutter_test/flutter_test.dart';
import '../lib/automation_rules.dart';

void main() {
  test('automation selects highest matched threshold', () {
    const engine = HardwareAutomationEngine(<HardwareAutomationRule>[
      HardwareAutomationRule(name: 'warm', sensor: 'cpuTemperature', threshold: 70, fanPercent: 50),
      HardwareAutomationRule(name: 'hot', sensor: 'cpuTemperature', threshold: 85, fanPercent: 90),
    ]);
    expect(engine.evaluate(<String, dynamic>{'cpuTemperature': 90}), 90);
  });

  test('disabled rule is ignored', () {
    const engine = HardwareAutomationEngine(<HardwareAutomationRule>[
      HardwareAutomationRule(name: 'disabled', sensor: 'gpuTemperature', threshold: 70, fanPercent: 90, enabled: false),
    ]);
    expect(engine.evaluate(<String, dynamic>{'gpuTemperature': 90}), isNull);
  });
}
