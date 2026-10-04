import 'dart:math' as math;
import 'package:flutter/material.dart';

class BenchmarkResult {
  const BenchmarkResult({required this.durationMs, required this.iterations, required this.score});
  final int durationMs;
  final int iterations;
  final double score;
}

class HardwareBenchmarkDialog extends StatefulWidget {
  const HardwareBenchmarkDialog({super.key});

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hardware Benchmark'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1 saniyelik CPU mikro-benchmark. Bu test stress test değildir ve donanım ayarlarını değiştirmez.'),
            const SizedBox(height: 18),
            if (_running) const LinearProgressIndicator(),
            if (_result case final result?) ...[
              Text('Skor: ${result.score.toStringAsFixed(0)} iterasyon/s'),
              Text('İterasyon: ${result.iterations}'),
              Text('Süre: ${result.durationMs} ms'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _running ? null : () => Navigator.pop(context), child: const Text('Kapat')),
        FilledButton.icon(onPressed: _running ? null : _run, icon: const Icon(Icons.speed), label: const Text('Çalıştır')),
      ],
    );
  }
}
