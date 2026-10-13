import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

class BenchmarkResult {
  const BenchmarkResult({
    required this.durationMs,
    required this.iterations,
    required this.score,
    required this.sampleScores,
  });

  final int durationMs;
  final int iterations;
  /// Median throughput across independent samples; less sensitive to one noisy run.
  final double score;
  final List<double> sampleScores;

  double get spreadPercent {
    if (sampleScores.length < 2 || score <= 0) return 0;
    final sorted = [...sampleScores]..sort();
    return (sorted.last - sorted.first) / score * 100;
  }
}

/// Runs in a worker isolate so the dashboard remains responsive during a test.
/// This benchmark is CPU-only and does not change clocks, voltage, power limits,
/// fan settings, or process priorities.
Map<String, num> _runBenchmarkSample(int targetDurationMs) {
  final stopwatch = Stopwatch()..start();
  var iterations = 0;
  var value = 0.5;
  while (stopwatch.elapsedMilliseconds < targetDurationMs) {
    value = math.sin(value + iterations * 0.000001) *
            math.cos(value + 0.0001) +
        1.0;
    iterations++;
  }
  stopwatch.stop();
  final elapsed = math.max(1, stopwatch.elapsedMilliseconds);
  return <String, num>{
    'durationMs': elapsed,
    'iterations': iterations,
    'score': iterations / elapsed * 1000.0,
  };
}

class HardwareBenchmarkDialog extends StatefulWidget {
  const HardwareBenchmarkDialog({
    super.key,
    this.translations = const <String, String>{},
  });

  final Map<String, String> translations;

  @override
  State<HardwareBenchmarkDialog> createState() =>
      _HardwareBenchmarkDialogState();
}

class _HardwareBenchmarkDialogState extends State<HardwareBenchmarkDialog> {
  static const int _sampleCount = 3;
  static const int _sampleDurationMs = 750;

  bool _running = false;
  BenchmarkResult? _result;
  String? _error;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _result = null;
      _error = null;
    });

    try {
      final samples = <Map<String, num>>[];
      for (var i = 0; i < _sampleCount; i++) {
        samples.add(await compute(_runBenchmarkSample, _sampleDurationMs));
      }
      final scores = samples.map((sample) => sample['score']!.toDouble()).toList()
        ..sort();
      final median = scores[scores.length ~/ 2];
      final medianSample = samples.reduce((left, right) {
        final leftDistance = (left['score']! - median).abs();
        final rightDistance = (right['score']! - median).abs();
        return leftDistance <= rightDistance ? left : right;
      });
      if (!mounted) return;
      setState(() {
        _result = BenchmarkResult(
          durationMs: medianSample['durationMs']!.round(),
          iterations: medianSample['iterations']!.round(),
          score: median,
          sampleScores: List<double>.unmodifiable(scores),
        );
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Benchmark failed: $error';
        _running = false;
      });
    }
  }

  String _tr(String key) => widget.translations[key] ?? key;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_tr('hardwareBenchmark')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('benchmarkDisclaimer')),
            const SizedBox(height: 18),
            if (_running) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text('Running $_sampleCount isolated CPU samples…'),
            ],
            if (_error != null) Text(_error!),
            if (_result case final result?) ...[
              Text(AppLocalizations.of(context).score(result.score.toStringAsFixed(0))),
              Text(AppLocalizations.of(context).iterations(result.iterations)),
              Text(AppLocalizations.of(context).duration(result.durationMs.toString())),
              const SizedBox(height: 8),
              Text('Median of $_sampleCount runs'),
              Text('Run-to-run spread: ±${(result.spreadPercent / 2).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.pop(context),
          child: Text(_tr('close')),
        ),
        FilledButton.icon(
          onPressed: _running ? null : _run,
          icon: const Icon(Icons.speed),
          label: Text(_tr('run')),
        ),
      ],
    );
  }
}
