import 'package:hwcontrol_dashboard/fan_curve.dart';

/// Sanitized runtime description of one hardware fan output.
class FanChannelTelemetry {
  const FanChannelTelemetry({
    required this.id,
    required this.name,
    required this.backend,
    required this.supported,
    required this.fanRpm,
    required this.rpmAvailable,
    required this.fanPercent,
    required this.percentAvailable,
    required this.reason,
  });

  final String id;
  final String name;
  final String backend;
  final bool supported;
  final double fanRpm;
  final bool rpmAvailable;
  final double fanPercent;
  final bool percentAvailable;
  final String reason;

  static final RegExp _validId = RegExp(r'^[0-9a-f]{16}$');

  factory FanChannelTelemetry.fromJson(Map<String, dynamic> value) {
    final id = value['id'] is String ? value['id'] as String : '';
    final backend =
        value['backend'] is String ? value['backend'] as String : 'monitor-only';
    final rpm = (value['fanRpm'] as num?)?.toDouble() ?? 0.0;
    final percent = (value['fanPercent'] as num?)?.toDouble() ?? 0.0;
    final rpmAvailable = value['rpmAvailable'] == true &&
        rpm.isFinite &&
        rpm >= 0;
    final percentAvailable = value['percentAvailable'] == true &&
        percent.isFinite &&
        percent >= 0 &&
        percent <= 100;
    return FanChannelTelemetry(
      id: _validId.hasMatch(id) ? id : '',
      name: value['name'] is String && (value['name'] as String).trim().isNotEmpty
          ? (value['name'] as String).trim()
          : 'Fan channel',
      backend: backend,
      supported: value['supported'] == true &&
          _validId.hasMatch(id) &&
          backend.isNotEmpty &&
          backend != 'monitor-only',
      fanRpm: rpmAvailable ? rpm : 0.0,
      rpmAvailable: rpmAvailable,
      fanPercent: percentAvailable ? percent.clamp(0, 100).toDouble() : 0.0,
      percentAvailable: percentAvailable,
      reason: value['reason'] is String ? value['reason'] as String : '',
    );
  }
}

/// Persisted per-channel behavior. The sensor choice is deliberate:
/// hottest preserves the CPU/GPU maximum behavior; users can bind a fan to
/// CPU or GPU temperature when that sensor is available.
class FanChannelProfile {
  const FanChannelProfile({
    required this.curve,
    this.sensorSource = 'hottest',
    this.automaticEnabled = true,
    this.manualPercent = 50,
  });

  final FanCurve curve;
  final String sensorSource;
  final bool automaticEnabled;
  final double manualPercent;

  static const supportedSensors = <String>{
    'hottest',
    'cpuTemperature',
    'gpuTemperature',
  };

  factory FanChannelProfile.fromJson(
    dynamic value, {
    FanCurve fallbackCurve = FanCurve.balanced,
  }) {
    if (value is! Map) {
      return FanChannelProfile(curve: fallbackCurve);
    }
    final source = value['sensor'] is String
        ? value['sensor'] as String
        : 'hottest';
    final percent = (value['manualPercent'] as num?)?.toDouble() ?? 50.0;
    final rawCurve = value['curve'];
    return FanChannelProfile(
      curve: rawCurve is List ? FanCurve.fromJson(rawCurve).normalized() : fallbackCurve,
      sensorSource: supportedSensors.contains(source) ? source : 'hottest',
      automaticEnabled: value['automaticEnabled'] is bool
          ? value['automaticEnabled'] as bool
          : true,
      manualPercent: percent.isFinite ? percent.clamp(20, 100).toDouble() : 50.0,
    );
  }

  FanChannelProfile copyWith({
    FanCurve? curve,
    String? sensorSource,
    bool? automaticEnabled,
    double? manualPercent,
  }) {
    return FanChannelProfile(
      curve: curve ?? this.curve,
      sensorSource: sensorSource ?? this.sensorSource,
      automaticEnabled: automaticEnabled ?? this.automaticEnabled,
      manualPercent: manualPercent == null
          ? this.manualPercent
          : (manualPercent.isFinite
              ? manualPercent.clamp(20, 100).toDouble()
              : this.manualPercent),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'curve': curve.toJson(),
        'sensor': sensorSource,
        'automaticEnabled': automaticEnabled,
        'manualPercent': manualPercent,
      };
}

FanCurve fanCurvePreset(String preset) {
  switch (preset) {
    case 'quiet':
      return const FanCurve(<FanCurvePoint>[
        FanCurvePoint(40, 20),
        FanCurvePoint(55, 20),
        FanCurvePoint(65, 30),
        FanCurvePoint(75, 45),
        FanCurvePoint(85, 70),
        FanCurvePoint(92, 100),
      ]);
    case 'performance':
      return const FanCurve(<FanCurvePoint>[
        FanCurvePoint(30, 35),
        FanCurvePoint(45, 50),
        FanCurvePoint(55, 65),
        FanCurvePoint(65, 80),
        FanCurvePoint(75, 95),
        FanCurvePoint(85, 100),
      ]);
    case 'balanced':
    default:
      return FanCurve.balanced;
  }
}

bool isUsableFanTemperature(double? temperature) =>
    temperature != null &&
    temperature.isFinite &&
    temperature > 0 &&
    temperature <= 125;

double? selectFanControlTemperature({
  required String sensorSource,
  required double cpuTemperature,
  required double gpuTemperature,
}) {
  final cpuValid = isUsableFanTemperature(cpuTemperature);
  final gpuValid = isUsableFanTemperature(gpuTemperature);
  switch (sensorSource) {
    case 'cpuTemperature':
      return cpuValid ? cpuTemperature : null;
    case 'gpuTemperature':
      return gpuValid ? gpuTemperature : null;
    case 'hottest':
      if (cpuValid && gpuValid) {
        return cpuTemperature >= gpuTemperature ? cpuTemperature : gpuTemperature;
      }
      if (cpuValid) return cpuTemperature;
      if (gpuValid) return gpuTemperature;
      return null;
    default:
      return null;
  }
}
