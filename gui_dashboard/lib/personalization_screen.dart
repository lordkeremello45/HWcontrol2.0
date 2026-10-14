import 'package:flutter/material.dart';

import 'ui_preferences.dart';
import 'user_data_store.dart';

/// Local appearance and dashboard preferences; this screen never sends hardware commands.
class HWControlPersonalizationScreen extends StatefulWidget {
  const HWControlPersonalizationScreen({super.key, this.store, this.onSaved});
  final HWControlUserDataStore? store;
  final ValueChanged<Map<String, dynamic>>? onSaved;

  @override
  State<HWControlPersonalizationScreen> createState() => _HWControlPersonalizationScreenState();
}

class _HWControlPersonalizationScreenState extends State<HWControlPersonalizationScreen> {
  late final HWControlUserDataStore _store = widget.store ?? HWControlUserDataStore();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _themeMode = 'dark';
  int _accent = HWControlUiPreferences.defaultAccentColorValue;
  double _fontScale = 1;
  String _density = 'comfortable';
  bool _animations = true;
  double _animationSpeed = 1;
  bool _sounds = true;
  String _temperatureUnit = 'C';
  String _graphWindow = '60s';
  String _startPage = 'dashboard';
  final Map<String, bool> _visibleCards = <String, bool>{
    'cpu': true, 'gpu': true, 'memory': true, 'disk': true, 'fan': true, 'battery': true,
  };
  final List<int> _palette = <int>[
    0xFF64D8CB, 0xFF4FC3F7, 0xFF9575CD, 0xFFFF6B6B,
    0xFFFFB74D, 0xFF81C784, 0xFFEC407A, 0xFF90A4AE,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await _store.readUiPreferences();
      if (!mounted) return;
      setState(() {
        final mode = values['themeMode'];
        _themeMode = mode is String && <String>{'dark', 'light', 'system'}.contains(mode)
            ? mode : ((values['darkMode'] is bool && values['darkMode'] == false) ? 'light' : 'dark');
        _accent = _resolveAccent(values['accentColor']);
        final scale = values['fontScale'];
        _fontScale = scale is num && scale.isFinite ? scale.toDouble().clamp(0.85, 1.3) : 1;
        _density = values['density'] == 'compact' ? 'compact' : 'comfortable';
        _animations = values['animationsEnabled'] is bool ? values['animationsEnabled'] as bool : true;
        final speed = values['animationSpeed'];
        _animationSpeed = speed is num && speed.isFinite ? speed.toDouble().clamp(0.5, 1.5) : 1;
        _sounds = values['uiSoundsEnabled'] is bool ? values['uiSoundsEnabled'] as bool : true;
        _temperatureUnit = values['temperatureUnit'] == 'F' ? 'F' : 'C';
        final window = values['graphWindow'];
        _graphWindow = <String>{'30s', '60s', '5m', '15m'}.contains(window) ? window as String : '60s';
        final start = values['startPage'];
        _startPage = <String>{'dashboard', 'profiles', 'graphs'}.contains(start) ? start as String : 'dashboard';
        final cards = values['visibleCards'];
        if (cards is Map) {
          for (final key in _visibleCards.keys.toList()) {
            if (cards[key] is bool) _visibleCards[key] = cards[key] as bool;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Preferences could not be read. Existing data has not been reset.';
      });
    }
  }

  int _resolveAccent(Object? value) {
    if (value is int && value >= 0xFF000000 && value <= 0xFFFFFFFF) return value;
    return HWControlUiPreferences.defaultAccentColorValue;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    final values = <String, dynamic>{
      'themeMode': _themeMode,
      'darkMode': _themeMode != 'light',
      'accentColor': _accent,
      'fontScale': double.parse(_fontScale.toStringAsFixed(2)),
      'density': _density,
      'animationsEnabled': _animations,
      'animationSpeed': double.parse(_animationSpeed.toStringAsFixed(2)),
      'uiSoundsEnabled': _sounds,
      'temperatureUnit': _temperatureUnit,
      'graphWindow': _graphWindow,
      'startPage': _startPage,
      'visibleCards': Map<String, bool>.from(_visibleCards),
    };
    try {
      final existing = await _store.readUiPreferences();
      await _store.writeUiPreferences(<String, dynamic>{...existing, ...values});
      if (!mounted) return;
      widget.onSaved?.call(values);
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personalization preferences saved.')));
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'Could not save preferences. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Localizations.localeOf(context).languageCode == 'tr';
    String text(String en, String trText) => tr ? trText : en;
    return Scaffold(
      appBar: AppBar(
        title: Text(text('Personalization', 'Kişiselleştirme')),
        actions: [
          IconButton(tooltip: text('Save preferences', 'Tercihleri kaydet'), onPressed: _loading || _saving ? null : _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
          _section(title: text('Appearance', 'Görünüm'), icon: Icons.palette_outlined, children: [
            Text(text('Theme', 'Tema'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'dark', label: Text(text('Dark', 'Koyu')), icon: const Icon(Icons.dark_mode_outlined)),
                ButtonSegment(value: 'light', label: Text(text('Light', 'Açık')), icon: const Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: 'system', label: Text(text('System', 'Sistem')), icon: const Icon(Icons.settings_suggest_outlined)),
              ],
              selected: <String>{_themeMode},
              onSelectionChanged: (value) => setState(() => _themeMode = value.first),
            ),
            const SizedBox(height: 18),
            Text(text('Accent color', 'Vurgu rengi'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final color in _palette)
                InkWell(
                  onTap: () => setState(() => _accent = color),
                  customBorder: const CircleBorder(),
                  child: Semantics(
                    button: true, selected: _accent == color,
                    label: 'Accent ' + color.toRadixString(16),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Color(color), shape: BoxShape.circle,
                        border: Border.all(color: _accent == color ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                      ),
                      child: _accent == color ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            Text(text('Text size', 'Yazı boyutu') + ': ' + (_fontScale * 100).round().toString() + '%'),
            Slider(value: _fontScale, min: 0.85, max: 1.3, divisions: 9, label: (_fontScale * 100).round().toString() + '%', onChanged: (value) => setState(() => _fontScale = value)),
            DropdownButtonFormField<String>(
              initialValue: _density,
              decoration: InputDecoration(labelText: text('Layout density', 'Yerleşim yoğunluğu')),
              items: [
                DropdownMenuItem(value: 'comfortable', child: Text(text('Comfortable', 'Rahat'))),
                DropdownMenuItem(value: 'compact', child: Text(text('Compact', 'Kompakt'))),
              ],
              onChanged: (value) { if (value != null) setState(() => _density = value); },
            ),
          ]),
          _section(title: text('Motion and sound', 'Hareket ve ses'), icon: Icons.animation_outlined, children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(text('Animations', 'Animasyonlar')), subtitle: Text(text('Turn off motion effects for a calmer interface.', 'Daha sade bir arayüz için hareket efektlerini kapat.')), value: _animations, onChanged: (value) => setState(() => _animations = value)),
            Text(text('Animation speed', 'Animasyon hızı') + ': ' + _animationSpeed.toStringAsFixed(1) + '×'),
            Slider(value: _animationSpeed, min: 0.5, max: 1.5, divisions: 4, label: _animationSpeed.toStringAsFixed(1) + '×', onChanged: (value) => setState(() => _animationSpeed = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(text('Interface sounds', 'Arayüz sesleri')), subtitle: Text(text('UI effects only; no hardware action is triggered here.', 'Yalnızca arayüz sesleri; buradan donanım işlemi başlatılmaz.')), value: _sounds, onChanged: (value) => setState(() => _sounds = value)),
          ]),
          _section(title: text('Dashboard', 'Gösterge paneli'), icon: Icons.dashboard_customize_outlined, children: [
            DropdownButtonFormField<String>(
              initialValue: _temperatureUnit,
              decoration: InputDecoration(labelText: text('Temperature unit', 'Sıcaklık birimi')),
              items: const [DropdownMenuItem(value: 'C', child: Text('°C — Celsius')), DropdownMenuItem(value: 'F', child: Text('°F — Fahrenheit'))],
              onChanged: (value) { if (value != null) setState(() => _temperatureUnit = value); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _graphWindow,
              decoration: InputDecoration(labelText: text('Graph time range', 'Grafik zaman aralığı')),
              items: const [
                DropdownMenuItem(value: '30s', child: Text('30 seconds')),
                DropdownMenuItem(value: '60s', child: Text('60 seconds')),
                DropdownMenuItem(value: '5m', child: Text('5 minutes')),
                DropdownMenuItem(value: '15m', child: Text('15 minutes')),
              ],
              onChanged: (value) { if (value != null) setState(() => _graphWindow = value); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _startPage,
              decoration: InputDecoration(labelText: text('Startup page', 'Başlangıç sayfası')),
              items: [
                DropdownMenuItem(value: 'dashboard', child: Text(text('Dashboard', 'Gösterge paneli'))),
                DropdownMenuItem(value: 'profiles', child: Text(text('Profiles', 'Profiller'))),
                DropdownMenuItem(value: 'graphs', child: Text(text('Graphs', 'Grafikler'))),
              ],
              onChanged: (value) { if (value != null) setState(() => _startPage = value); },
            ),
            const Divider(height: 24),
            Text(text('Visible metric cards', 'Görüntülenecek ölçüm kartları'), style: Theme.of(context).textTheme.titleSmall),
            for (final entry in <String, String>{'cpu': 'CPU', 'gpu': 'GPU', 'memory': text('Memory', 'Bellek'), 'disk': text('Disk', 'Disk'), 'fan': text('Fan', 'Fan'), 'battery': text('Battery', 'Pil')}.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero, title: Text(entry.value), value: _visibleCards[entry.key] ?? true,
                onChanged: (value) {
                  if (_visibleCards.values.where((visible) => visible).length == 1 && !value) return;
                  setState(() => _visibleCards[entry.key] = value);
                },
              ),
            Text(text('At least one metric card must remain visible.', 'En az bir ölçüm kartı görünür kalmalıdır.'), style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(text('Save preferences', 'Tercihleri kaydet'))),
        ],
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleLarge)]),
          const Divider(height: 24),
          ...children,
        ]),
      ),
    );
  }
}
