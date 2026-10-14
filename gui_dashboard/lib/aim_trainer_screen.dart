import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'user_data_store.dart';

/// Offline, UI-only target practice. It never communicates with the hardware bridge.
class HWAimTrainerScreen extends StatefulWidget {
  const HWAimTrainerScreen({
    super.key,
    required this.store,
    this.sessionSeconds = 30,
    this.random,
  });

  final HWControlUserDataStore store;
  final int sessionSeconds;
  final math.Random Function()? random;

  @override
  State<HWAimTrainerScreen> createState() => _HWAimTrainerScreenState();
}

class _HWAimTrainerScreenState extends State<HWAimTrainerScreen> {
  static const _historyKey = 'aimTrainerHistory';
  late final math.Random _random = widget.random?.call() ?? math.Random();
  final Stopwatch _stopwatch = Stopwatch();
  final List<int> _reactionTimesMs = <int>[];
  Timer? _ticker;
  bool _running = false;
  bool _finished = false;
  int _hits = 0;
  int _misses = 0;
  int _remainingSeconds = 30;
  int _targetSize = 54;
  DateTime? _targetSpawnedAt;
  double _targetX = 0.5;
  double _targetY = 0.5;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  int get _attempts => _hits + _misses;
  double get _accuracy => _attempts == 0 ? 0 : _hits / _attempts * 100;
  int get _averageReactionMs {
    if (_reactionTimesMs.isEmpty) return 0;
    return (_reactionTimesMs.reduce((a, b) => a + b) / _reactionTimesMs.length).round();
  }

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.sessionSeconds.clamp(5, 120).toInt();
    _loadHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final preferences = await widget.store.readUiPreferences();
      final raw = preferences[_historyKey];
      if (!mounted || raw is! List) return;
      final valid = <Map<String, dynamic>>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final hits = entry['hits'];
        final misses = entry['misses'];
        final accuracy = entry['accuracy'];
        final reaction = entry['averageReactionMs'];
        final duration = entry['durationSeconds'];
        if (hits is int && misses is int && accuracy is num &&
            reaction is int && duration is int &&
            hits >= 0 && misses >= 0 && reaction >= 0 && duration > 0) {
          valid.add(<String, dynamic>{
            'hits': hits,
            'misses': misses,
            'accuracy': accuracy.toDouble().clamp(0, 100),
            'averageReactionMs': reaction,
            'durationSeconds': duration,
          });
        }
        if (valid.length >= 20) break;
      }
      setState(() => _history = valid);
    } catch (_) {
      // History is optional; a storage problem must not block training.
    }
  }

  void _placeTarget() {
    // Keep the full target inside the arena, with room for a visible hit area.
    _targetX = 0.08 + _random.nextDouble() * 0.84;
    _targetY = 0.10 + _random.nextDouble() * 0.80;
    _targetSpawnedAt = DateTime.now();
  }

  void _start() {
    _ticker?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _reactionTimesMs.clear();
    setState(() {
      _hits = 0;
      _misses = 0;
      _remainingSeconds = widget.sessionSeconds.clamp(5, 120).toInt();
      _running = true;
      _finished = false;
      _placeTarget();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final remaining = widget.sessionSeconds -
          _stopwatch.elapsed.inMilliseconds ~/ 1000;
      if (remaining <= 0) {
        _finish();
      } else if (mounted) {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  void _finish() {
    if (!_running) return;
    _ticker?.cancel();
    _stopwatch.stop();
    final result = <String, dynamic>{
      'hits': _hits,
      'misses': _misses,
      'accuracy': double.parse(_accuracy.toStringAsFixed(1)),
      'averageReactionMs': _averageReactionMs,
      'durationSeconds': widget.sessionSeconds.clamp(5, 120),
    };
    setState(() {
      _running = false;
      _finished = true;
      _remainingSeconds = 0;
      _history = <Map<String, dynamic>>[result, ..._history].take(20).toList();
    });
    unawaited(_persistHistory());
  }

  Future<void> _persistHistory() async {
    try {
      final preferences = await widget.store.readUiPreferences();
      await widget.store.writeUiPreferences(<String, dynamic>{
        ...preferences,
        _historyKey: _history,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session finished, but history could not be saved.')),
        );
      }
    }
  }

  void _hitTarget() {
    if (!_running) return;
    final spawnedAt = _targetSpawnedAt;
    if (spawnedAt != null) {
      _reactionTimesMs.add(DateTime.now().difference(spawnedAt).inMilliseconds);
    }
    setState(() {
      _hits++;
      _placeTarget();
    });
  }

  void _missTarget() {
    if (_running) setState(() => _misses++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aim Trainer'),
        actions: [
          IconButton(
            tooltip: 'Session history',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => _buildHistorySheet(context),
            ),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offline target practice', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    const Text('Train your mouse accuracy and reaction time. This is a practice simulation; it does not control games or hardware.'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric(label: 'Time left', value: '${_remainingSeconds}s'),
                        _Metric(label: 'Hits', value: '$_hits'),
                        _Metric(label: 'Accuracy', value: '${_accuracy.toStringAsFixed(1)}%'),
                        _Metric(label: 'Avg. reaction', value: _reactionTimesMs.isEmpty ? '—' : '${_averageReactionMs} ms'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        key: const ValueKey('aim-arena'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _missTarget,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(color: accent.withAlpha(110)),
                          ),
                          child: CustomPaint(painter: _ArenaGridPainter(color: accent.withAlpha(28))),
                        ),
                      ),
                      if (_running)
                        Positioned(
                          left: (_targetX * constraints.maxWidth - _targetSize / 2)
                              .clamp(0.0, constraints.maxWidth - _targetSize),
                          top: (_targetY * constraints.maxHeight - _targetSize / 2)
                              .clamp(0.0, constraints.maxHeight - _targetSize),
                          width: _targetSize.toDouble(),
                          height: _targetSize.toDouble(),
                          child: Semantics(
                            button: true,
                            label: 'Practice target',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey('aim-target'),
                                customBorder: const CircleBorder(),
                                onTap: _hitTarget,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent,
                                    border: Border.all(color: theme.colorScheme.onPrimary, width: 3),
                                    boxShadow: [BoxShadow(color: accent.withAlpha(90), blurRadius: 14, spreadRadius: 2)],
                                  ),
                                  child: Icon(Icons.adjust, color: theme.colorScheme.onPrimary, size: 30),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!_running)
                        Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_finished ? Icons.flag_outlined : Icons.gps_fixed, size: 36, color: accent),
                                  const SizedBox(height: 8),
                                  Text(_finished ? 'Session complete' : 'Ready to train', style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 6),
                                  Text(_finished ? '$_hits hits · ${_accuracy.toStringAsFixed(1)}% accuracy' : 'Hit the target as quickly and accurately as you can.'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    key: const ValueKey('aim-start'),
                                    onPressed: _start,
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(_finished ? 'Train again' : 'Start 30-second session'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Missed taps count as misses. Reaction time is measured from target appearance to a successful hit.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySheet(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent sessions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                const Text('No sessions yet. Complete a practice session to see your results here.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return ListTile(
                        leading: const Icon(Icons.gps_fixed),
                        title: Text('${item['hits']} hits · ${(item['accuracy'] as num).toStringAsFixed(1)}% accuracy'),
                        subtitle: Text('${item['durationSeconds']} s · ${item['averageReactionMs']} ms average reaction'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 105),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _ArenaGridPainter extends CustomPainter {
  const _ArenaGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaGridPainter oldDelegate) => color != oldDelegate.color;
}
