import 'dart:async';
import 'package:flutter/material.dart';
import 'user_data_store.dart';

/// First UI milestone for Audio Controller Studio.
///
/// This screen edits and persists a local DSP profile. It deliberately does not
/// claim live capture, system-wide processing, or device routing until the
/// native device adapters and bridge contract are implemented.
class AudioControllerStudioScreen extends StatefulWidget {
  const AudioControllerStudioScreen({super.key});

  @override
  State<AudioControllerStudioScreen> createState() => _AudioControllerStudioScreenState();
}

class _AudioControllerStudioScreenState extends State<AudioControllerStudioScreen> {
  final HWControlUserDataStore _store = HWControlUserDataStore();
  double _inputGain = 0;
  double _gateThreshold = -48;
  double _compressorThreshold = -12;
  double _limiterCeiling = -1;
  final List<double> _eqGain = <double>[0, 0, 0];
  final List<double> _eqFrequency = <double>[100, 1000, 8000];
  bool _gateEnabled = false;
  bool _compressorEnabled = false;
  bool _limiterEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String _preset = 'Neutral';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final preferences = await _store.readUiPreferences();
      final raw = preferences['audioStudioConfig'];
      if (raw is Map) {
        setState(() {
          _inputGain = _number(raw['inputGain'], 0).clamp(-24, 12).toDouble();
          _gateThreshold = _number(raw['gateThreshold'], -48).clamp(-90, 0).toDouble();
          _compressorThreshold = _number(raw['compressorThreshold'], -12).clamp(-60, 0).toDouble();
          _limiterCeiling = _number(raw['limiterCeiling'], -1).clamp(-24, 0).toDouble();
          _gateEnabled = raw['gateEnabled'] == true;
          _compressorEnabled = raw['compressorEnabled'] == true;
          _limiterEnabled = raw['limiterEnabled'] != false;
          _preset = raw['preset'] is String ? raw['preset'] as String : 'Custom';
          final gains = raw['eqGain'];
          final frequencies = raw['eqFrequency'];
          if (gains is List && gains.length == 3) {
            for (var i = 0; i < 3; i++) {
              _eqGain[i] = _number(gains[i], 0).clamp(-12, 12).toDouble();
            }
          }
          if (frequencies is List && frequencies.length == 3) {
            for (var i = 0; i < 3; i++) {
              _eqFrequency[i] = _number(frequencies[i], _eqFrequency[i]).clamp(20, 18000).toDouble();
            }
          }
        });
      }
    } catch (_) {
      // Corrupt optional audio preferences must not prevent the dashboard opening.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _number(dynamic value, double fallback) {
    if (value is num && value.toDouble().isFinite) return value.toDouble();
    return fallback;
  }

  Map<String, dynamic> _configuration() => <String, dynamic>{
    'schemaVersion': 1,
    'preset': _preset,
    'inputGain': _inputGain,
    'gateThreshold': _gateThreshold,
    'compressorThreshold': _compressorThreshold,
    'limiterCeiling': _limiterCeiling,
    'gateEnabled': _gateEnabled,
    'compressorEnabled': _compressorEnabled,
    'limiterEnabled': _limiterEnabled,
    'eqGain': List<double>.from(_eqGain),
    'eqFrequency': List<double>.from(_eqFrequency),
  };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final preferences = await _store.readUiPreferences();
      await _store.writeUiPreferences(<String, dynamic>{
        ...preferences,
        'audioStudioConfig': _configuration(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio profile saved locally. Live audio backend is not connected yet.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the audio profile.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyPreset(String preset) {
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'Voice':
          _inputGain = 3;
          _eqGain[0] = -2;
          _eqGain[1] = 2;
          _eqGain[2] = 1;
          _gateEnabled = true;
          _compressorEnabled = true;
          _limiterEnabled = true;
          break;
        case 'Gaming':
          _inputGain = 0;
          _eqGain[0] = 2;
          _eqGain[1] = 0;
          _eqGain[2] = 2;
          _gateEnabled = false;
          _compressorEnabled = false;
          _limiterEnabled = true;
          break;
        case 'Broadcast':
          _inputGain = 0;
          _eqGain[0] = -1;
          _eqGain[1] = 2;
          _eqGain[2] = 1;
          _gateEnabled = true;
          _compressorEnabled = true;
          _limiterEnabled = true;
          break;
        default:
          _inputGain = 0;
          for (var i = 0; i < 3; i++) {
            _eqGain[i] = 0;
          }
          _gateEnabled = false;
          _compressorEnabled = false;
          _limiterEnabled = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Controller Studio'),
        actions: [
          IconButton(
            tooltip: 'Save local profile',
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 820;
                return SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 16 : 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusBanner(scheme),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final preset in const ['Neutral', 'Voice', 'Gaming', 'Broadcast'])
                                ChoiceChip(
                                  label: Text(preset),
                                  selected: _preset == preset,
                                  onSelected: (_) => _applyPreset(preset),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (compact) ...[
                            _buildEqPanel(),
                            const SizedBox(height: 16),
                            _buildDynamicsPanel(),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildEqPanel()),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _buildDynamicsPanel()),
                              ],
                            ),
                          const SizedBox(height: 16),
                          _buildAnalysisPanel(),
                          const SizedBox(height: 16),
                          _buildRoutingPanel(),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _statusBanner(ColorScheme scheme) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: scheme.tertiaryContainer.withAlpha(100),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile editor • DSP integration in progress', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('These settings are saved locally. Microphone capture, system-audio routing, live meters and effects are not active until the native audio backend is connected. No audio is being recorded.'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _panel({required String title, required String subtitle, required IconData icon, required Widget child}) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ])),
              ]),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );

  Widget _buildEqPanel() => _panel(
    title: 'Parametric equalizer',
    subtitle: 'Three peaking bands • gain and center frequency',
    icon: Icons.graphic_eq,
    child: Column(
      children: [
        _slider('Input gain', _inputGain, -24, 12, (v) => setState(() { _inputGain = v; _preset = 'Custom'; }), suffix: 'dB'),
        const Divider(),
        for (var i = 0; i < 3; i++) ...[
          Row(children: [
            Expanded(child: Text(['Low band', 'Mid band', 'High band'][i], style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${_eqGain[i].toStringAsFixed(1)} dB', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ]),
          Slider(
            value: _eqGain[i],
            min: -12,
            max: 12,
            divisions: 48,
            label: '${_eqGain[i].toStringAsFixed(1)} dB',
            onChanged: (v) => setState(() { _eqGain[i] = v; _preset = 'Custom'; }),
          ),
          Row(children: [
            Text('Center frequency'),
            const Spacer(),
            Text('${_eqFrequency[i].round()} Hz'),
          ]),
          Slider(
            value: _eqFrequency[i].clamp(20, 18000).toDouble(),
            min: 20,
            max: 18000,
            divisions: 1798,
            onChanged: (v) => setState(() { _eqFrequency[i] = v; _preset = 'Custom'; }),
          ),
          if (i != 2) const Divider(),
        ],
      ],
    ),
  );

  Widget _buildDynamicsPanel() => _panel(
    title: 'Dynamics and safety',
    subtitle: 'Settings preview; live processing is not connected',
    icon: Icons.tune,
    child: Column(
      children: [
        _slider('Noise gate threshold', _gateThreshold, -90, 0, (v) => setState(() { _gateThreshold = v; _preset = 'Custom'; }), suffix: 'dB'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Noise gate'), subtitle: const Text('Basic threshold gate; not AI noise removal.'), value: _gateEnabled, onChanged: (v) => setState(() { _gateEnabled = v; _preset = 'Custom'; })),
        const Divider(),
        _slider('Compressor threshold', _compressorThreshold, -60, 0, (v) => setState(() { _compressorThreshold = v; _preset = 'Custom'; }), suffix: 'dB'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Compressor'), value: _compressorEnabled, onChanged: (v) => setState(() { _compressorEnabled = v; _preset = 'Custom'; })),
        const Divider(),
        _slider('Limiter ceiling', _limiterCeiling, -24, 0, (v) => setState(() { _limiterCeiling = v; _preset = 'Custom'; }), suffix: 'dBFS'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Output limiter'), subtitle: const Text('Hard sample-peak clamp in the current native prototype.'), value: _limiterEnabled, onChanged: (v) => setState(() { _limiterEnabled = v; _preset = 'Custom'; })),
      ],
    ),
  );

  Widget _buildAnalysisPanel() => _panel(
    title: 'Analysis laboratory',
    subtitle: 'Live analysis becomes available with device integration',
    icon: Icons.monitor_heart_outlined,
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metric('Input peak', 'Not connected'),
        _metric('Output peak', 'Not connected'),
        _metric('RMS / LUFS', 'Not connected'),
        _metric('FFT / spectrogram', 'Not connected'),
        _metric('Latency / dropout', 'Not connected'),
        _metric('Clipping counter', 'Not connected'),
      ],
    ),
  );

  Widget _buildRoutingPanel() => _panel(
    title: 'Devices and routing',
    subtitle: 'Capture, processing and routing are separate capabilities',
    icon: Icons.route_outlined,
    child: Column(
      children: const [
        _capabilityRow('Microphone capture', 'NOT IMPLEMENTED', Icons.mic_none),
        Divider(),
        _capabilityRow('System audio capture', 'NOT IMPLEMENTED', Icons.speaker_group_outlined),
        Divider(),
        _capabilityRow('Per-application routing', 'NOT IMPLEMENTED', Icons.alt_route),
        Divider(),
        _capabilityRow('Virtual microphone / output', 'NOT IMPLEMENTED', Icons.settings_input_component),
        Divider(),
        _capabilityRow('Noise reduction / echo cancellation', 'PLANNED', Icons.spatial_audio_off),
        Divider(),
        _capabilityRow('Spatial audio / HRTF', 'PLANNED', Icons.surround_sound),
      ],
    ),
  );

  Widget _slider(String title, double value, double min, double max, ValueChanged<double> changed, {String suffix = ''}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title)),
            Text('${value.toStringAsFixed(1)} $suffix', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
          ]),
          Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, onChanged: changed),
        ],
      );

  Widget _metric(String label, String value) => Container(
    width: 190,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );
}

class _capabilityRow extends StatelessWidget {
  const _capabilityRow(this.label, this.status, this.icon);
  final String label;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20),
    const SizedBox(width: 10),
    Expanded(child: Text(label)),
    Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: status == 'NOT IMPLEMENTED' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}
