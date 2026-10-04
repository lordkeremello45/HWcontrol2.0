class HardwareAutomationRule {
  const HardwareAutomationRule({required this.name, required this.sensor, required this.threshold, required this.fanPercent, this.enabled = true});
  final String name;
  final String sensor;
  final double threshold;
  final double fanPercent;
  final bool enabled;

  Map<String, dynamic> toJson() => {'name': name, 'sensor': sensor, 'threshold': threshold, 'fan': fanPercent, 'enabled': enabled};

  static HardwareAutomationRule? fromJson(dynamic value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim();
    final sensor = value['sensor']?.toString().trim();
    final threshold = (value['threshold'] as num?)?.toDouble();
    final fan = (value['fan'] as num?)?.toDouble();
    final enabled = value['enabled'] is bool ? value['enabled'] as bool : true;
    if (name == null || name.isEmpty || sensor == null || sensor.isEmpty || threshold == null || fan == null) return null;
    if (!threshold.isFinite || !fan.isFinite || fan < 0 || fan > 100) return null;
    if (sensor != 'cpuTemperature' && sensor != 'gpuTemperature') return null;
    return HardwareAutomationRule(name: name, sensor: sensor, threshold: threshold.clamp(20, 110), fanPercent: fan, enabled: enabled);
  }
}

class HardwareAutomationEngine {
  const HardwareAutomationEngine(this.rules);
  final List<HardwareAutomationRule> rules;

  double? evaluate(Map<String, dynamic> telemetry) {
    double? target;
    double? matchedThreshold;
    for (final rule in rules) {
      if (!rule.enabled) continue;
      final value = (telemetry[rule.sensor] as num?)?.toDouble();
      if (value == null || !value.isFinite || value < rule.threshold) continue;
      if (matchedThreshold == null || rule.threshold > matchedThreshold) {
        matchedThreshold = rule.threshold;
        target = rule.fanPercent;
      }
    }
    return target?.clamp(0, 100);
  }
}
