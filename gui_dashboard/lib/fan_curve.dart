import 'package:flutter/material.dart';

class FanCurvePoint {
  const FanCurvePoint(this.temperature, this.fanPercent);
  final double temperature;
  final double fanPercent;

  Map<String, double> toJson() => <String, double>{
        'temperature': temperature,
        'fan': fanPercent,
      };

  static FanCurvePoint? fromJson(dynamic value) {
    if (value is! Map) return null;
    final temperature = (value['temperature'] as num?)?.toDouble();
    final fan = (value['fan'] as num?)?.toDouble();
    if (temperature == null || fan == null) return null;
    if (!temperature.isFinite || !fan.isFinite) return null;
    return FanCurvePoint(temperature.clamp(20, 110).toDouble(), fan.clamp(0, 100).toDouble());
  }
}

class FanCurve {
  const FanCurve(this.points);
  final List<FanCurvePoint> points;

  static const FanCurve balanced = FanCurve(<FanCurvePoint>[
    FanCurvePoint(40, 25),
    FanCurvePoint(55, 35),
    FanCurvePoint(65, 50),
    FanCurvePoint(75, 65),
    FanCurvePoint(85, 80),
    FanCurvePoint(92, 100),
  ]);

  double evaluate(double temperature) {
    if (points.isEmpty) return 0;
    final sorted = [...points]..sort((a, b) => a.temperature.compareTo(b.temperature));
    if (temperature <= sorted.first.temperature) return sorted.first.fanPercent;
    if (temperature >= sorted.last.temperature) return sorted.last.fanPercent;
    for (var i = 1; i < sorted.length; i++) {
      final left = sorted[i - 1];
      final right = sorted[i];
      if (temperature <= right.temperature) {
        final span = right.temperature - left.temperature;
        if (span <= 0) return right.fanPercent;
        final ratio = (temperature - left.temperature) / span;
        return (left.fanPercent + (right.fanPercent - left.fanPercent) * ratio).clamp(0, 100).toDouble();
      }
    }
    return sorted.last.fanPercent;
  }

  List<Map<String, double>> toJson() =>
      points.map((point) => point.toJson()).toList(growable: false);

  static FanCurve fromJson(dynamic value) {
    if (value is! List) return FanCurve.balanced;
    final points = value.map(FanCurvePoint.fromJson).whereType<FanCurvePoint>().toList();
    if (points.length < 2) return FanCurve.balanced;
    points.sort((a, b) => a.temperature.compareTo(b.temperature));
    return FanCurve(points);
  }
}

class FanCurveController {
  FanCurveController({
    this.minFanPercent = 20,
    this.maxFanPercent = 100,
    this.minimumChangePercent = 3,
    this.minimumCommandInterval = const Duration(seconds: 2),
    this.smoothingSamples = 3,
  });

  final double minFanPercent;
  final double maxFanPercent;
  final double minimumChangePercent;
  final Duration minimumCommandInterval;
  final int smoothingSamples;
  final List<double> _temperatures = <double>[];
  double? _lastTarget;
  DateTime? _lastCommandAt;

  void reset() {
    _temperatures.clear();
    _lastTarget = null;
    _lastCommandAt = null;
  }

  double? nextTarget({
    required FanCurve curve,
    required double temperature,
    required DateTime now,
    required bool sensorValid,
    required bool hardwareControlSupported,
  }) {
    if (!sensorValid || !temperature.isFinite || !hardwareControlSupported) {
      reset();
      return null;
    }
    _temperatures.add(temperature);
    while (_temperatures.length > smoothingSamples) {
      _temperatures.removeAt(0);
    }
    final smoothed = _temperatures.reduce((a, b) => a + b) / _temperatures.length;
    final target = curve.evaluate(smoothed).clamp(minFanPercent, maxFanPercent).toDouble();
    if (_lastTarget != null && (target - _lastTarget!).abs() < minimumChangePercent) return null;
    if (_lastCommandAt != null && now.difference(_lastCommandAt!) < minimumCommandInterval) return null;
    _lastTarget = target;
    _lastCommandAt = now;
    return target;
  }
}

class FanCurveEditor extends StatefulWidget {
  const FanCurveEditor({super.key, required this.initialCurve, required this.onSave});
  final FanCurve initialCurve;
  final ValueChanged<FanCurve> onSave;

  @override
  State<FanCurveEditor> createState() => _FanCurveEditorState();
}

class _FanCurveEditorState extends State<FanCurveEditor> {
  late List<FanCurvePoint> _points;

  @override
  void initState() {
    super.initState();
    _points = [...widget.initialCurve.points];
  }

  void _sort() => _points.sort((a, b) => a.temperature.compareTo(b.temperature));

  Future<void> _addPoint() async {
    final temperature = TextEditingController(text: '70');
    final fan = TextEditingController(text: '60');
    final result = await showDialog<List<double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni fan eğrisi noktası'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: temperature, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sıcaklık °C')),
            TextField(controller: fan, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fan %')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final t = double.tryParse(temperature.text);
              final f = double.tryParse(fan.text);
              if (t != null && f != null) Navigator.pop(context, <double>[t, f]);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    temperature.dispose();
    fan.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _points.add(FanCurvePoint(result[0].clamp(20, 110).toDouble(), result[1].clamp(0, 100).toDouble()));
      _sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Smart Fan Curve'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text('Sıcaklığa göre fan hedefini tanımlayın. Uygulama yalnızca doğrulanmış hardware-control backend mevcutsa eğriyi otomatik uygular.'),
              const SizedBox(height: 12),
              for (var i = 0; i < _points.length; i++)
                Row(
                  children: [
                    Expanded(child: Text('${_points[i].temperature.toStringAsFixed(0)} °C')),
                    Expanded(
                      flex: 2,
                      child: Slider(
                        value: _points[i].fanPercent,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_points[i].fanPercent.round()}%',
                        onChanged: (value) => setState(() => _points[i] = FanCurvePoint(_points[i].temperature, value)),
                      ),
                    ),
                    SizedBox(width: 50, child: Text('${_points[i].fanPercent.round()}%')),
                    IconButton(
                      tooltip: 'Noktayı sil',
                      onPressed: _points.length <= 2 ? null : () => setState(() => _points.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              Row(
                children: [
                  TextButton.icon(onPressed: _addPoint, icon: const Icon(Icons.add), label: const Text('Nokta ekle')),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _points = [...FanCurve.balanced.points]), child: const Text('Dengeliye sıfırla')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        FilledButton(
          onPressed: _points.length < 2 ? null : () {
            _sort();
            widget.onSave(FanCurve(List<FanCurvePoint>.unmodifiable(_points)));
            Navigator.pop(context);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
