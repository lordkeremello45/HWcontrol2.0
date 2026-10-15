import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'user_data_store.dart';

/// Offline aim practice. This screen is self-contained and never sends game,
/// input-injection, or hardware-control commands.
class HWAimTrainerScreen extends StatefulWidget {
  const HWAimTrainerScreen({
    super.key,
    required this.store,
    this.sessionSeconds = 30,
    this.random,
    this.onSessionSaved,
  }) : assert(sessionSeconds > 0);

  final HWControlUserDataStore store;
  final int sessionSeconds;
  final math.Random Function()? random;
  final VoidCallback? onSessionSaved;

  @override
  State<HWAimTrainerScreen> createState() => _HWAimTrainerScreenState();
}

class _HWAimTrainerScreenState extends State<HWAimTrainerScreen> {
  late final math.Random _random = widget.random?.call() ?? math.Random();
  Timer? _timer;
  int _remaining = 0;
  int _hits = 0;
  int _misses = 0;
  bool _running = false;
  bool _complete = false;
  double _targetX = 0.5;
  double _targetY = 0.5;

  void _moveTarget() {
    _targetX = 0.12 + _random.nextDouble() * 0.76;
    _targetY = 0.12 + _random.nextDouble() * 0.76;
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _remaining = widget.sessionSeconds;
      _hits = 0;
      _misses = 0;
      _running = true;
      _complete = false;
      _moveTarget();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
          _complete = true;
        });
        unawaited(_saveSession());
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _hit() {
    if (!_running) return;
    setState(() {
      _hits++;
      _moveTarget();
    });
  }

  void _miss() {
    if (!_running) return;
    setState(() => _misses++);
  }

  Future<void> _saveSession() async {
    final preferences = await widget.store.readUiPreferences();
    final existing = preferences['aimTrainerHistory'];
    final history = existing is List
        ? existing.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList()
        : <Map<String, dynamic>>[];
    history.add(<String, dynamic>{
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'durationSeconds': widget.sessionSeconds,
      'hits': _hits,
      'misses': _misses,
    });
    if (history.length > 50) {
      history.removeRange(0, history.length - 50);
    }
    await widget.store.writeUiPreferences(<String, dynamic>{
      ...preferences,
      'aimTrainerHistory': history,
    });
    widget.onSessionSaved?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aim Trainer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Offline practice; this does not control games or hardware.'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(child: Text('Hits: $_hits')),
                Expanded(child: Text('Misses: $_misses')),
                Text(_running ? '${_remaining}s' : _complete ? 'Complete' : '${widget.sessionSeconds}s'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _miss,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: <Widget>[
                        if (_running)
                          Positioned(
                            left: (constraints.maxWidth - 52) * _targetX,
                            top: (constraints.maxHeight - 52) * _targetY,
                            child: GestureDetector(
                              key: const ValueKey('aim-target'),
                              onTap: _hit,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        if (!_running)
                          Center(
                            child: Text(
                              _complete ? 'Session complete' : 'Ready when you are',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('aim-start'),
              onPressed: _running ? null : _start,
              child: Text(_complete ? 'Play again' : 'Start session'),
            ),
          ],
        ),
      ),
    );
  }
}
