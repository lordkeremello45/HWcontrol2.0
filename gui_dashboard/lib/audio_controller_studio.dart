import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'user_data_store.dart';

/// First UI milestone for Audio Controller Studio.
///
/// This screen edits and persists a local DSP profile. It deliberately does not
/// claim live capture, system-wide processing, or device routing until the
/// native device adapters and bridge contract are implemented.
class AudioControllerStudioScreen extends StatefulWidget {
  const AudioControllerStudioScreen({super.key, this.onRecommend, this.onLoadDevices});

  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> profile)? onRecommend;
  final Future<Map<String, dynamic>?> Function()? onLoadDevices;

  @override
  State<AudioControllerStudioScreen> createState() => _AudioControllerStudioScreenState();
}

class _AudioControllerStudioScreenState extends State<AudioControllerStudioScreen> {
  final HWControlUserDataStore _store = HWControlUserDataStore();
  final TextEditingController _deviceModelController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  String _deviceType = 'microphone';
  String _usage = 'voice';
  int _sampleRateHz = 48000;
  int _channels = 1;
  bool _specificationsVerified = false;
  bool _advisorLoading = false;
  String? _advisorError;
  String? _deviceDetectionMessage;
  String? _selectedEndpointId;
  List<Map<String, dynamic>> _captureDevices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _playbackDevices = <Map<String, dynamic>>[];
  Map<String, dynamic>? _advisorRecommendation;
  double _inputGain = 0;
  double _gateThreshold = -48;
  double _compressorThreshold = -12;
  double _compressorAttack = 10;
  double _compressorRelease = 100;
  double _compressorKnee = 6;
  double _highPassFrequency = 80;
  double _limiterCeiling = -1;
  final List<double> _eqGain = <double>[0, 0, 0];
  final List<double> _eqFrequency = <double>[100, 1000, 8000];
  bool _gateEnabled = false;
  bool _compressorEnabled = false;
  bool _highPassEnabled = false;
  bool _limiterEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String _preset = 'Neutral';

  @override
  void dispose() {
    _deviceModelController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadAudioDevices());
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
          _compressorAttack = _number(raw['compressorAttack'], 10).clamp(0.1, 200).toDouble();
          _compressorRelease = _number(raw['compressorRelease'], 100).clamp(1, 2000).toDouble();
          _compressorKnee = _number(raw['compressorKnee'], 6).clamp(0, 24).toDouble();
          _highPassFrequency = _number(raw['highPassFrequency'], 80).clamp(20, 1000).toDouble();
          _limiterCeiling = _number(raw['limiterCeiling'], -1).clamp(-24, 0).toDouble();
          _gateEnabled = raw['gateEnabled'] == true;
          _compressorEnabled = raw['compressorEnabled'] == true;
          _highPassEnabled = raw['highPassEnabled'] == true;
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
    'compressorAttack': _compressorAttack,
    'compressorRelease': _compressorRelease,
    'compressorKnee': _compressorKnee,
    'highPassFrequency': _highPassFrequency,
    'highPassEnabled': _highPassEnabled,
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
          _highPassEnabled = true;
          _limiterEnabled = true;
          break;
        case 'Gaming':
          _inputGain = 0;
          _eqGain[0] = 2;
          _eqGain[1] = 0;
          _eqGain[2] = 2;
          _gateEnabled = false;
          _compressorEnabled = false;
          _highPassEnabled = false;
          _limiterEnabled = true;
          break;
        case 'Broadcast':
          _inputGain = 0;
          _eqGain[0] = -1;
          _eqGain[1] = 2;
          _eqGain[2] = 1;
          _gateEnabled = true;
          _compressorEnabled = true;
          _highPassEnabled = true;
          _limiterEnabled = true;
          break;
        default:
          _inputGain = 0;
          for (var i = 0; i < 3; i++) {
            _eqGain[i] = 0;
          }
          _gateEnabled = false;
          _compressorEnabled = false;
          _highPassEnabled = false;
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
                          _buildDeviceIntelligencePanel(),
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



  List<Map<String, dynamic>> get _endpointOptions {
    final source = _deviceType == 'microphone'
        ? _captureDevices
        : _deviceType == 'headset'
            ? <Map<String, dynamic>>[..._captureDevices, ..._playbackDevices]
            : _playbackDevices;
    return source.map((device) {
      final direction = device['direction'] as String? ?? '';
      return <String, dynamic>{
        ...device,
        'id': '$direction:${device['index']}',
      };
    }).toList(growable: false);
  }

  Future<void> _loadAudioDevices() async {
    if (widget.onLoadDevices == null) {
      if (mounted) setState(() => _deviceDetectionMessage = 'Bridge device detection is not available in this context.');
      return;
    }
    try {
      final result = await widget.onLoadDevices!();
      if (result == null) throw const FormatException('Bridge did not return audio devices.');
      List<Map<String, dynamic>> parse(Object? raw, String direction) {
        if (raw is! List) throw const FormatException('Invalid device list.');
        return raw.whereType<Map>().map((item) => <String, dynamic>{
          'index': item['index'] is num ? (item['index'] as num).toInt() : -1,
          'name': item['name'] is String ? item['name'] as String : '',
          'isDefault': item['isDefault'] == true,
          'direction': direction,
        }).where((item) => (item['index'] as int) >= 0 && (item['name'] as String).isNotEmpty).toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _captureDevices = parse(result['capture'], 'capture');
        _playbackDevices = parse(result['playback'], 'playback');
        _deviceDetectionMessage = 'Detected ${_captureDevices.length} input and ${_playbackDevices.length} output endpoints on this computer.';
      });
      _syncSelectedEndpoint();
    } catch (error) {
      if (mounted) setState(() => _deviceDetectionMessage = 'Device detection unavailable: $error');
    }
  }

  void _syncSelectedEndpoint() {
    final options = _endpointOptions;
    if (options.isEmpty) {
      setState(() => _selectedEndpointId = null);
      return;
    }
    final selectedMatches = options.where((device) => device['id'] == _selectedEndpointId);
    final defaultMatches = options.where((item) => item['isDefault'] == true);
    final device = selectedMatches.isNotEmpty
        ? selectedMatches.first
        : defaultMatches.isNotEmpty
            ? defaultMatches.first
            : options.first;
    setState(() {
      _selectedEndpointId = device['id'] as String;
      _deviceModelController.text = device['name'] as String;
    });
  }

  Widget _buildDeviceIntelligencePanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.auto_awesome),
            SizedBox(width: 8),
            Text('Device intelligence', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text('Gemma runs locally through the authenticated bridge. Enter the endpoint name and capabilities reported by your operating system; do not guess specifications. Suggestions are advisory and are never applied automatically.'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(_deviceDetectionMessage ?? 'Detecting audio endpoints…')),
            IconButton(
              tooltip: 'Refresh audio devices',
              onPressed: _advisorLoading ? null : _loadAudioDevices,
              icon: const Icon(Icons.refresh),
            ),
          ]),
          if (_endpointOptions.isNotEmpty) DropdownButtonFormField<String>(
            value: _endpointOptions.any((item) => item['id'] == _selectedEndpointId) ? _selectedEndpointId : null,
            decoration: const InputDecoration(labelText: 'Detected audio endpoint'),
            items: [
              for (final device in _endpointOptions)
                DropdownMenuItem<String>(
                  value: device['id'] as String,
                  child: Text('${device['name'] as String}${device['isDefault'] == true ? ' (default)' : ''}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              final matches = _endpointOptions.where((item) => item['id'] == value);
              if (matches.isEmpty) return;
              final selected = matches.first;
              setState(() {
                _selectedEndpointId = value;
                _deviceModelController.text = selected['name'] as String;
              });
            },
          ),
          TextField(
            controller: _deviceModelController,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Device model / endpoint name', hintText: 'e.g. USB Audio Device'),
          ),
          TextField(
            controller: _manufacturerController,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Manufacturer (optional)'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              value: _deviceType,
              decoration: const InputDecoration(labelText: 'Device type'),
              items: const [
                DropdownMenuItem(value: 'microphone', child: Text('Microphone')),
                DropdownMenuItem(value: 'speaker', child: Text('Speaker')),
                DropdownMenuItem(value: 'headphones', child: Text('Headphones')),
                DropdownMenuItem(value: 'headset', child: Text('Headset')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _deviceType = value);
                _syncSelectedEndpoint();
              },
            )),
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              value: _usage,
              decoration: const InputDecoration(labelText: 'Use case'),
              items: const [
                DropdownMenuItem(value: 'voice', child: Text('Voice / calls')),
                DropdownMenuItem(value: 'gaming', child: Text('Gaming')),
                DropdownMenuItem(value: 'music', child: Text('Music')),
                DropdownMenuItem(value: 'movie', child: Text('Movies')),
                DropdownMenuItem(value: 'meeting', child: Text('Meetings')),
                DropdownMenuItem(value: 'streaming', child: Text('Streaming')),
              ],
              onChanged: (value) => setState(() { if (value != null) _usage = value; }),
            )),
            SizedBox(width: 180, child: DropdownButtonFormField<int>(
              value: _sampleRateHz,
              decoration: const InputDecoration(labelText: 'Sample rate (reported)'),
              items: const [
                DropdownMenuItem(value: 16000, child: Text('16 kHz')),
                DropdownMenuItem(value: 44100, child: Text('44.1 kHz')),
                DropdownMenuItem(value: 48000, child: Text('48 kHz')),
                DropdownMenuItem(value: 96000, child: Text('96 kHz')),
                DropdownMenuItem(value: 192000, child: Text('192 kHz')),
              ],
              onChanged: (value) => setState(() { if (value != null) _sampleRateHz = value; }),
            )),
            SizedBox(width: 160, child: DropdownButtonFormField<int>(
              value: _channels,
              decoration: const InputDecoration(labelText: 'Channels (reported)'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Mono (1)')),
                DropdownMenuItem(value: 2, child: Text('Stereo (2)')),
                DropdownMenuItem(value: 4, child: Text('4 channels')),
                DropdownMenuItem(value: 6, child: Text('5.1 (6)')),
                DropdownMenuItem(value: 8, child: Text('7.1 (8)')),
              ],
              onChanged: (value) => setState(() { if (value != null) _channels = value; }),
            )),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _specificationsVerified,
            onChanged: (value) => setState(() => _specificationsVerified = value ?? false),
            title: const Text('I verified these capabilities in system/device settings'),
            subtitle: const Text('If unchecked, Gemma must treat the supplied specifications as unverified.'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _advisorLoading || widget.onRecommend == null ? null : _requestDeviceRecommendation,
              icon: _advisorLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Ask local Gemma'),
            ),
          ),
          if (widget.onRecommend == null) const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('The local bridge callback is not available in this context.'),
          ),
          if (_advisorError != null) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_advisorError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          if (_advisorRecommendation != null) ...[
            const Divider(height: 24),
            Text((_advisorRecommendation!['summary'] as String?) ?? 'Gemma recommendation', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (_advisorRecommendation!['warnings'] is List)
              for (final warning in (_advisorRecommendation!['warnings'] as List).whereType<String>())
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $warning')),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _applyAdvisorRecommendation,
              icon: const Icon(Icons.tune),
              label: const Text('Apply validated settings'),
            ),
            const SizedBox(height: 6),
            const Text('Settings change only after you approve them; save the profile separately.'),
          ],
        ],
      ),
    ),
  );

  Future<void> _requestDeviceRecommendation() async {
    final model = _deviceModelController.text.trim();
    if (model.isEmpty || widget.onRecommend == null) {
      setState(() => _advisorError = 'Enter the device model or endpoint name first.');
      return;
    }
    setState(() {
      _advisorLoading = true;
      _advisorError = null;
      _advisorRecommendation = null;
    });
    try {
      final result = await widget.onRecommend!({
        'deviceType': _deviceType,
        'model': model,
        'manufacturer': _manufacturerController.text.trim(),
        'usage': _usage,
        'sampleRateHz': _sampleRateHz,
        'channels': _channels,
        'specificationsVerified': _specificationsVerified,
      });
      final raw = result?['recommendation'];
      if (raw is! String) throw const FormatException('Gemma returned no recommendation.');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || !_isSafeRecommendation(decoded)) {
        throw const FormatException('Gemma output did not match the allowed audio-profile schema.');
      }
      if (!mounted) return;
      setState(() => _advisorRecommendation = decoded);
    } catch (error) {
      if (!mounted) return;
      setState(() => _advisorError = 'Recommendation rejected: $error');
    } finally {
      if (mounted) setState(() => _advisorLoading = false);
    }
  }

  bool _isSafeRecommendation(Map<String, dynamic> value) {
    bool numberIn(String key, double min, double max) {
      final v = value[key];
      return v is num && v.isFinite && v >= min && v <= max;
    }
    if (value['summary'] is! String || (value['summary'] as String).length > 500) return false;
    if (!numberIn('inputGainDb', -12, 6) ||
        !numberIn('highPassHz', 20, 300) ||
        !numberIn('noiseGateThresholdDb', -90, -20) ||
        !numberIn('compressorRatio', 1, 4) ||
        !numberIn('limiterCeilingDb', -6, -0.5)) return false;
    for (final key in ['highPassEnabled', 'noiseGateEnabled', 'compressorEnabled', 'limiterEnabled']) {
      if (value[key] is! bool) return false;
    }
    final bands = value['eqBands'];
    if (bands is! List || bands.length > 3) return false;
    for (final band in bands) {
      if (band is! Map || band['frequencyHz'] is! num || band['gainDb'] is! num) return false;
      final frequency = (band['frequencyHz'] as num).toDouble();
      final gain = (band['gainDb'] as num).toDouble();
      if (!frequency.isFinite || frequency < 20 || frequency > 18000 || !gain.isFinite || gain < -6 || gain > 6) return false;
    }
    final warnings = value['warnings'];
    if (warnings is! List || warnings.length > 8 || warnings.any((item) => item is! String || item.length > 240)) return false;
    return true;
  }

  void _applyAdvisorRecommendation() {
    final value = _advisorRecommendation;
    if (value == null || !_isSafeRecommendation(value)) return;
    setState(() {
      _inputGain = (value['inputGainDb'] as num).toDouble();
      _highPassFrequency = (value['highPassHz'] as num).toDouble();
      _highPassEnabled = value['highPassEnabled'] as bool;
      _gateThreshold = (value['noiseGateThresholdDb'] as num).toDouble();
      _gateEnabled = value['noiseGateEnabled'] as bool;
      _compressorEnabled = value['compressorEnabled'] as bool;
      _limiterEnabled = value['limiterEnabled'] as bool;
      _limiterCeiling = (value['limiterCeilingDb'] as num).toDouble();
      final bands = value['eqBands'] as List;
      for (var i = 0; i < 3; i++) {
        if (i < bands.length) {
          final band = bands[i] as Map;
          _eqFrequency[i] = (band['frequencyHz'] as num).toDouble();
          _eqGain[i] = (band['gainDb'] as num).toDouble();
        } else {
          _eqGain[i] = 0;
        }
      }
      _preset = 'Gemma';
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Validated Gemma settings applied to the editor. Save the profile to keep them.')));
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
              Text('These settings are saved locally. The native device-host prototype can enumerate and open capture/playback devices, but this screen is not connected to it yet. System-audio routing and live UI meters are not active. No audio is being recorded. No audio is being recorded.'),
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
        _slider('High-pass frequency', _highPassFrequency, 20, 1000, (v) => setState(() { _highPassFrequency = v; _preset = 'Custom'; }), suffix: 'Hz'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('High-pass filter'), subtitle: const Text('Reduces low-frequency rumble.'), value: _highPassEnabled, onChanged: (v) => setState(() { _highPassEnabled = v; _preset = 'Custom'; })),
        const Divider(),
        _slider('Compressor threshold', _compressorThreshold, -60, 0, (v) => setState(() { _compressorThreshold = v; _preset = 'Custom'; }), suffix: 'dB'),
        _slider('Attack', _compressorAttack, 0.1, 200, (v) => setState(() { _compressorAttack = v; _preset = 'Custom'; }), suffix: 'ms'),
        _slider('Release', _compressorRelease, 1, 2000, (v) => setState(() { _compressorRelease = v; _preset = 'Custom'; }), suffix: 'ms'),
        _slider('Soft-knee width', _compressorKnee, 0, 24, (v) => setState(() { _compressorKnee = v; _preset = 'Custom'; }), suffix: 'dB'),
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
        _CapabilityRow('Microphone capture / playback', 'NATIVE PROTOTYPE', Icons.mic_none),
        Divider(),
        _CapabilityRow('System audio capture', 'NOT IMPLEMENTED', Icons.speaker_group_outlined),
        Divider(),
        _CapabilityRow('Per-application routing', 'NOT IMPLEMENTED', Icons.alt_route),
        Divider(),
        _CapabilityRow('Virtual microphone / output', 'NOT IMPLEMENTED', Icons.settings_input_component),
        Divider(),
        _CapabilityRow('Noise reduction / echo cancellation', 'PLANNED', Icons.spatial_audio_off),
        Divider(),
        _CapabilityRow('Spatial audio / HRTF', 'PLANNED', Icons.surround_sound),
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

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow(this.label, this.status, this.icon);
  final String label;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20),
    const SizedBox(width: 10),
    Expanded(child: Text(label)),
    Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: status == 'NOT IMPLEMENTED' ? Theme.of(context).colorScheme.error : status == 'NATIVE PROTOTYPE' ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}
