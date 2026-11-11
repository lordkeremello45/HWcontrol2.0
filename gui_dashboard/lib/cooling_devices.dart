import 'package:flutter/material.dart';

class LiquidCoolingReading {
  const LiquidCoolingReading({
    required this.kind,
    required this.value,
    required this.unit,
  });

  final String kind;
  final double value;
  final String unit;

  factory LiquidCoolingReading.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    final value = raw is num ? raw.toDouble() : double.nan;
    return LiquidCoolingReading(
      kind: json['kind'] is String ? json['kind'] as String : '',
      value: value,
      unit: json['unit'] is String ? json['unit'] as String : '',
    );
  }
}

class LiquidCoolingDeviceTelemetry {
  const LiquidCoolingDeviceTelemetry({
    required this.name,
    required this.state,
    required this.readings,
    this.reason = '',
  });

  final String name;
  final String state;
  final List<LiquidCoolingReading> readings;
  final String reason;

  factory LiquidCoolingDeviceTelemetry.fromJson(Map<String, dynamic> json) {
    final rawReadings = json['readings'];
    final readings = rawReadings is List
        ? rawReadings
            .whereType<Map>()
            .map((value) => LiquidCoolingReading.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .where((reading) =>
                reading.kind.isNotEmpty &&
                reading.value.isFinite &&
                reading.unit.isNotEmpty)
            .toList(growable: false)
        : const <LiquidCoolingReading>[];
    return LiquidCoolingDeviceTelemetry(
      name: json['name'] is String && (json['name'] as String).trim().isNotEmpty
          ? (json['name'] as String).trim()
          : 'Liquid-cooling controller',
      state: json['state'] is String ? json['state'] as String : 'partial',
      readings: readings,
      reason: json['reason'] is String ? json['reason'] as String : '',
    );
  }
}

class LiquidCoolingSnapshot {
  const LiquidCoolingSnapshot({
    required this.state,
    required this.backend,
    required this.reason,
    required this.devices,
  });

  const LiquidCoolingSnapshot.unavailable()
      : state = 'unavailable',
        backend = 'liquidctl',
        reason = 'Optional liquidctl telemetry is unavailable.',
        devices = const <LiquidCoolingDeviceTelemetry>[];

  final String state;
  final String backend;
  final String reason;
  final List<LiquidCoolingDeviceTelemetry> devices;

  LiquidCoolingSnapshot asStale() {
    if (devices.isEmpty) return this;
    return LiquidCoolingSnapshot(
      state: 'stale',
      backend: backend,
      reason: 'The last valid readings are being retained because refresh failed.',
      devices: devices,
    );
  }

  factory LiquidCoolingSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDevices = json['devices'];
    final devices = rawDevices is List
        ? rawDevices
            .whereType<Map>()
            .map((value) => LiquidCoolingDeviceTelemetry.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false)
        : const <LiquidCoolingDeviceTelemetry>[];
    return LiquidCoolingSnapshot(
      state: json['state'] is String ? json['state'] as String : 'unavailable',
      backend: json['backend'] is String ? json['backend'] as String : 'unknown',
      reason: json['reason'] is String ? json['reason'] as String : '',
      devices: devices,
    );
  }
}

class LiquidCoolingPanel extends StatelessWidget {
  const LiquidCoolingPanel({super.key, required this.snapshot});

  final LiquidCoolingSnapshot snapshot;

  String _labelFor(String kind) {
    switch (kind) {
      case 'coolantTemperature':
        return 'Coolant temperature';
      case 'pumpRPM':
        return 'Pump speed';
      case 'fanRPM':
        return 'Fan speed';
      case 'flowRate':
        return 'Coolant flow';
      case 'coolantLevel':
        return 'Coolant level';
      default:
        return kind;
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'available':
        return 'Available';
      case 'partial':
        return 'Partial';
      case 'stale':
        return 'Stale';
      default:
        return 'Unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Liquid-cooling telemetry',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _stateLabel(snapshot.state),
                  style: TextStyle(
                    color: snapshot.state == 'available'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (snapshot.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(snapshot.reason, style: theme.textTheme.bodySmall),
            ],
            for (final device in snapshot.devices) ...[
              const Divider(height: 18),
              Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (device.readings.isEmpty && device.reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(device.reason, style: theme.textTheme.bodySmall),
              ],
              if (device.readings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reading in device.readings)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${_labelFor(reading.kind)}: ${reading.value.toStringAsFixed(1)} ${reading.unit}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 4),
            Text(
              'Read-only adapter. HWcontrol does not initialize, reconfigure or control the detected device.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
