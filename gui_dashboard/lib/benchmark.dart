import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

class BenchmarkResult {
  const BenchmarkResult({required this.durationMs, required this.iterations, required this.score});
  final int durationMs;
  final int iterations;
  final double score;
}

class HardwareBenchmarkDialog extends StatefulWidget {
  const HardwareBenchmarkDialog({super.key, this.translations = const <String, String>{}});
  final Map<String, String> translations;

  @override
  State<HardwareBenchmarkDialog> createState() => _HardwareBenchmarkDialogState();
}

class _HardwareBenchmarkDialogState extends State<HardwareBenchmarkDialog> {
  bool _running = false;
  BenchmarkResult? _result;

  void _run() {
    if (_running) return;
    setState(() { _running = true; _result = null; });
    final stopwatch = Stopwatch()..start();
    var iterations = 0;
    var value = 0.5;
    // Bounded CPU-only microbenchmark; never changes hardware settings.
    while (stopwatch.elapsedMilliseconds < 1000) {
      value = math.sin(value + iterations * 0.000001) * math.cos(value + 0.0001) + 1.0;
      iterations++;
    }
    stopwatch.stop();
    final score = iterations / math.max(1, stopwatch.elapsedMilliseconds) * 1000.0;
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = BenchmarkResult(durationMs: stopwatch.elapsedMilliseconds, iterations: iterations, score: score);
    });
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
            if (_running) const LinearProgressIndicator(),
            if (_result case final result?) ...[
              Text(AppLocalizations.of(context).score(result.score.toStringAsFixed(0))),
              Text(AppLocalizations.of(context).iterations(result.iterations)), 
              Text(AppLocalizations.of(context).duration(result.durationMs.toString())), 
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _running ? null : () => Navigator.pop(context), child: Text(_tr('close'))),
        FilledButton.icon(onPressed: _running ? null : _run, icon: const Icon(Icons.speed), label: Text(_tr('run'))),
      ],
    );
  }
}
