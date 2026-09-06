import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const HWControlApp());

class HWControlApp extends StatefulWidget {
  const HWControlApp({super.key});

  @override
  State<HWControlApp> createState() => _HWControlAppState();
}

class _HWControlAppState extends State<HWControlApp> {
  bool _darkMode = true;
  bool _animationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(_darkMode),
      home: DashboardScreen(
        darkMode: _darkMode,
        animationsEnabled: _animationsEnabled,
        onThemeChanged: (value) => setState(() => _darkMode = value),
        onAnimationsChanged: (value) => setState(() => _animationsEnabled = value),
      ),
    );
  }

  ThemeData _buildTheme(bool darkMode) {
    final colors = darkMode
        ? const ColorScheme.dark(primary: Color(0xFF64D8CB), secondary: Color(0xFFFFB454), surface: Color(0xFF121920))
        : const ColorScheme.light(primary: Color(0xFF087F78), secondary: Color(0xFFB56800), surface: Color(0xFFFFFFFF));
    return ThemeData(
      brightness: darkMode ? Brightness.dark : Brightness.light,
      colorScheme: colors,
      scaffoldBackgroundColor: darkMode ? const Color(0xFF0A0E12) : const Color(0xFFF0F4F3),
      useMaterial3: true,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.darkMode, required this.animationsEnabled, required this.onThemeChanged, required this.onAnimationsChanged});

  final bool darkMode;
  final bool animationsEnabled;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onAnimationsChanged;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _compileTimeKey = String.fromEnvironment('HWCONTROL_KEY');
  static const _appVersion = '0.2.2';
  static const _checkFileUrl = 'https://raw.githubusercontent.com/lordkeremello45/HWcontrol2.0/main/updates/check.json';
  Socket? _socket;
  StreamIterator<String>? _responses;
  String _status = 'Bridge bekleniyor';
  String _lastAction = 'Henüz komut gönderilmedi';
  bool _isConnected = false;
  bool _isSending = false;
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;
  String _updateStatus = 'Güncellemeler kontrol edilmedi';
  double _fanValue = 50;
  double _aiValue = 80;
  double _temperatureLimit = 85;
  bool _notificationsEnabled = true;
  Timer? _metricsTimer;
  double _cpuUsage = 0;
  double _cpuTemperature = 0;
  double _memoryUsage = 0;
  double _diskUsage = 0;
  double _gpuUsage = 0;
  double _fanPercent = 0;
  String _modelDigest = 'Kontrol edilmedi';
  final List<_MetricSample> _history = <_MetricSample>[];
  final List<String> _events = <String>[];
  Map<String, Map<String, double>> _profiles = {};

  String get _sharedKey =>
      Platform.environment['HWCONTROL_KEY'] ?? _compileTimeKey;

  int get _bridgePort => int.tryParse(Platform.environment['HWCONTROL_PORT'] ?? '8080') ?? 8080;

  @override
  void initState() {
    super.initState();
    _connectToBridge();
    _checkForUpdate();
    _refreshSecurity();
    _loadProfiles();
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshMetrics());
  }

  Future<File> get _profilesFile async => File('hwcontrol_profiles.json');

  Future<void> _loadProfiles() async {
    try {
      final file = await _profilesFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _profiles = decoded.map((key, value) => MapEntry(key, Map<String, double>.from((value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))));
    } catch (_) {
      _addEvent('Profil dosyası okunamadı');
    }
  }

  Future<void> _saveProfile(String name) async {
    _profiles[name] = {'fan': _fanValue, 'ai': _aiValue};
    try {
      final file = await _profilesFile;
      await file.writeAsString(jsonEncode(_profiles));
      _addEvent('$name profili kaydedildi');
    } catch (_) {
      _addEvent('Profil kaydedilemedi');
    }
  }

  void _addEvent(String message) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)}  $message');
      if (_events.length > 20) _events.removeLast();
    });
  }

  Future<Map<String, dynamic>?> _requestBridgeData(String action) async {
    final socket = _socket;
    if (!_isConnected || socket == null || _sharedKey.isEmpty || _isSending) return null;
    _isSending = true;
    try {
      final payload = '$action\n0.000000';
      final auth = Hmac(sha256, utf8.encode(_sharedKey)).convert(utf8.encode(payload)).toString();
      socket.write('${jsonEncode({'action': action, 'value': 0.0, 'auth': auth})}\n');
      final responses = _responses;
      if (responses == null || !await responses.moveNext().timeout(const Duration(seconds: 4))) return null;
      final response = jsonDecode(responses.current) as Map<String, dynamic>;
      return response['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    } finally {
      _isSending = false;
    }
  }

  Future<void> _refreshMetrics() async {
    final data = await _requestBridgeData('Get Status');
    if (!mounted || data == null) return;
    final temperature = (data['cpuTemperature'] as num?)?.toDouble() ?? 0;
    final thresholdExceeded = _notificationsEnabled && temperature >= _temperatureLimit;
    setState(() {
      _cpuUsage = (data['cpuUsage'] as num?)?.toDouble() ?? 0;
      _cpuTemperature = temperature;
      _memoryUsage = (data['memoryUsage'] as num?)?.toDouble() ?? 0;
      _diskUsage = (data['diskUsage'] as num?)?.toDouble() ?? 0;
      _gpuUsage = (data['gpuUsage'] as num?)?.toDouble() ?? 0;
      _fanPercent = (data['fanPercent'] as num?)?.toDouble() ?? 0;
      _history.add(_MetricSample(DateTime.now(), temperature));
      if (_history.length > 720) _history.removeAt(0);
      if (thresholdExceeded) {
        _status = 'Sıcaklık uyarısı: ${temperature.toStringAsFixed(1)} °C';
      }
    });
    if (thresholdExceeded) _addEvent('CPU sıcaklığı eşik üstünde');
  }

  Future<void> _refreshSecurity() async {
    final data = await _requestBridgeData('Get Security');
    if (!mounted || data == null) return;
    setState(() => _modelDigest = data['modelSha256'] as String? ?? 'unavailable');
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    try {
      final manifestResponse = await http.get(Uri.parse(_checkFileUrl)).timeout(const Duration(seconds: 6));
      if (manifestResponse.statusCode != 200) throw StateError('manifest unavailable');
      final manifest = jsonDecode(manifestResponse.body) as Map<String, dynamic>;
      if (manifest['schema'] != 1 || manifest['repository'] != 'lordkeremello45/HWcontrol2.0') {
        throw StateError('untrusted update manifest');
      }
      final apiUrl = manifest['releases_api'] as String?;
      if (apiUrl == null || !apiUrl.startsWith('https://api.github.com/repos/lordkeremello45/HWcontrol2.0/')) {
        throw StateError('untrusted update endpoint');
      }
      final releasesResponse = await http.get(Uri.parse(apiUrl), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 6));
      if (releasesResponse.statusCode != 200) throw StateError('release check failed');
      final releases = jsonDecode(releasesResponse.body) as List<dynamic>;
      final suffix = Platform.isWindows ? '-windows' : Platform.isMacOS ? '-macos' : '-linux';
      UpdateInfo? newest;
      for (final item in releases) {
        final release = item as Map<String, dynamic>;
        final tag = release['tag_name'] as String? ?? '';
        final url = release['html_url'] as String? ?? '';
        if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+-(linux|windows|macos)$').hasMatch(tag) || !tag.endsWith(suffix) || !url.startsWith('https://github.com/lordkeremello45/HWcontrol2.0/releases/')) continue;
        final assets = (release['assets'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
        final hasChecksum = assets.any((asset) => (asset['name'] as String? ?? '').endsWith('.sha256'));
        if (!hasChecksum) continue;
        newest = UpdateInfo(tag: tag, releaseUrl: url);
        break;
      }
      if (!mounted) return;
      setState(() {
        _updateInfo = newest != null && _isNewerVersion(newest.tag, _appVersion) ? newest : null;
        _updateStatus = newest == null ? 'Güncel release bulunamadı' : _updateInfo == null ? 'Uygulama güncel' : 'Yeni sürüm hazır';
      });
      _addEvent('Bridge bağlantısı aktif');
    } catch (_) {
      if (mounted) setState(() => _updateStatus = 'Güncelleme kontrolü başarısız');
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  bool _isNewerVersion(String tag, String current) {
    final candidate = RegExp(r'^v([0-9]+)\.([0-9]+)\.([0-9]+)-').firstMatch(tag);
    final currentParts = current.split('.').map(int.parse).toList();
    if (candidate == null) return false;
    final nextParts = [int.parse(candidate.group(1)!), int.parse(candidate.group(2)!), int.parse(candidate.group(3)!)];
    for (var index = 0; index < 3; index++) {
      if (nextParts[index] != currentParts[index]) return nextParts[index] > currentParts[index];
    }
    return false;
  }

  Future<void> _openUpdate() async {
    final info = _updateInfo;
    if (info == null) return;
    final uri = Uri.parse(info.releaseUrl);
    if (!uri.isScheme('https') || uri.host != 'github.com') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSettings() async {
    var notificationsEnabled = _notificationsEnabled;
    var temperatureLimit = _temperatureLimit;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kullanıcı ayarları'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bildirimleri etkinleştir'),
                  value: notificationsEnabled,
                  onChanged: (value) => setDialogState(() => notificationsEnabled = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Sıcaklık uyarı eşiği')),
                    Text('${temperatureLimit.round()} °C', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: temperatureLimit,
                  min: 60,
                  max: 100,
                  divisions: 16,
                  label: '${temperatureLimit.round()} °C',
                  onChanged: (value) => setDialogState(() => temperatureLimit = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _notificationsEnabled = notificationsEnabled;
                  _temperatureLimit = temperatureLimit;
                });
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToBridge() async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        _bridgePort,
        timeout: const Duration(seconds: 3),
      );
      _socket = socket;
      _responses = StreamIterator(
        socket.map(utf8.decode).transform(const LineSplitter()),
      );
      socket.done.whenComplete(() {
        if (!mounted) return;
        setState(() {
          _isConnected = false;
          _status = 'Bridge bağlantısı kesildi';
        });
      });
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _status = 'Bridge aktif';
      });
      _addEvent('Bridge bağlantısı kurulamadı');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _status = 'Bridge bulunamadı';
      });
    }
  }

  Future<void> _sendCommand(String action, double value) async {
    final socket = _socket;
    if (!_isConnected || socket == null) {
      setState(() => _status = 'Önce bridge servisini başlatın');
      return;
    }
    if (_isSending) return;
    if (_sharedKey.isEmpty) {
      setState(() => _status = 'HWCONTROL_KEY ayarlı değil');
      return;
    }

    setState(() => _isSending = true);
    try {
      final payload = '$action\n${value.toStringAsFixed(6)}';
      final auth = Hmac(sha256, utf8.encode(_sharedKey))
          .convert(utf8.encode(payload))
          .toString();
      socket.write('${jsonEncode({
        'action': action,
        'value': value,
        'auth': auth,
      })}\n');

      final responses = _responses;
      if (responses == null ||
          !await responses.moveNext().timeout(const Duration(seconds: 3))) {
        throw StateError('Bridge response missing');
      }
      final response = jsonDecode(responses.current) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _status = response['message'] as String? ?? 'Yanıt alındı';
        _lastAction = '$action  •  %${value.round()}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Bridge yanıt vermedi');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _applyPreset(String name, double fan, double ai) async {
    if (_isSending) return;
    setState(() {
      _fanValue = fan;
      _aiValue = ai;
      _lastAction = '$name profili hazırlanıyor';
    });
    if (_profiles.containsKey(name)) {
      fan = _profiles[name]!['fan'] ?? fan;
      ai = _profiles[name]!['ai'] ?? ai;
      setState(() { _fanValue = fan; _aiValue = ai; });
    }
    await _sendCommand('Fan Hızı', fan);
    await _sendCommand('AI İşlem Gücü', ai);
    if (mounted) setState(() => _lastAction = '$name profili  •  fan %${fan.round()}  •  AI %${ai.round()}');
  }

  void _resetControls() {
    setState(() {
      _fanValue = 50;
      _aiValue = 80;
      _lastAction = 'Varsayılan değerler yüklendi';
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _responses?.cancel();
    _socket?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 18 : 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildUpdateCard(),
                      const SizedBox(height: 18),
                      _buildOverview(compact),
                      const SizedBox(height: 18),
                      _buildHistoryCard(),
                      const SizedBox(height: 18),
                      if (compact)
                        Column(
                          children: [
                            _buildControls(),
                            const SizedBox(height: 18),
                            _buildSystemCard(),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildControls()),
                            const SizedBox(width: 18),
                            Expanded(flex: 2, child: _buildSystemCard()),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF163B3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bolt, color: Color(0xFF64D8CB)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HWControl', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('Precision hardware control', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140), fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: widget.darkMode ? 'Light mode' : 'Dark mode',
          onPressed: () => widget.onThemeChanged(!widget.darkMode),
          icon: Icon(widget.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        IconButton(
          tooltip: widget.animationsEnabled ? 'Animasyonları kapat' : 'Animasyonları aç',
          onPressed: () => widget.onAnimationsChanged(!widget.animationsEnabled),
          icon: Icon(widget.animationsEnabled ? Icons.animation : Icons.animation_outlined),
        ),
        IconButton(tooltip: 'Kullanıcı ayarları', onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
        _buildConnectionBadge(),
      ],
    );
  }

  Widget _buildConnectionBadge() {
    final color = _isConnected ? const Color(0xFF64D8CB) : const Color(0xFFFF6B6B);
    return AnimatedSwitcher(
      duration: widget.animationsEnabled ? const Duration(milliseconds: 220) : Duration.zero,
      child: Container(
      key: ValueKey(_isConnected),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(_isConnected ? 'BRIDGE ONLINE' : 'OFFLINE', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
      ),
    );
  }

  Widget _buildUpdateCard() {
    final available = _updateInfo != null;
    final color = available ? const Color(0xFFFFB454) : const Color(0xFF64D8CB);
    return AnimatedSwitcher(
      duration: widget.animationsEnabled ? const Duration(milliseconds: 220) : Duration.zero,
      child: _Panel(
      key: ValueKey('$_updateStatus-${_updateInfo?.tag}'),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Icon(available ? Icons.system_update_alt : Icons.verified_user_outlined, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(available ? '${_updateInfo!.tag} hazır' : _updateStatus, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          if (available) TextButton.icon(onPressed: _openUpdate, icon: const Icon(Icons.download, size: 17), label: const Text('Release’i aç')),
          IconButton(tooltip: 'Güncellemeleri kontrol et', onPressed: _isCheckingUpdate ? null : _checkForUpdate, icon: const Icon(Icons.refresh)),
        ],
      ),
      ),
    );
  }

  Widget _buildOverview(bool compact) {
    final cards = [
      _MetricData('CPU sıcaklığı', _cpuTemperature.toStringAsFixed(1), '°C', Icons.thermostat, const Color(0xFFFFB454), (_cpuTemperature / 100).clamp(0, 1)),
      _MetricData('CPU kullanımı', _cpuUsage.toStringAsFixed(0), '%', Icons.memory, const Color(0xFF64D8CB), (_cpuUsage / 100).clamp(0, 1)),
      _MetricData('RAM kullanımı', _memoryUsage.toStringAsFixed(0), '%', Icons.storage, const Color(0xFF8FA7FF), (_memoryUsage / 100).clamp(0, 1)),
      _MetricData('Disk kullanımı', _diskUsage.toStringAsFixed(0), '%', Icons.save, const Color(0xFFB995FF), (_diskUsage / 100).clamp(0, 1)),
      _MetricData('GPU kullanımı', _gpuUsage.toStringAsFixed(0), '%', Icons.graphic_eq, const Color(0xFFFF8C69), (_gpuUsage / 100).clamp(0, 1)),
      _MetricData('Fan', _fanPercent.toStringAsFixed(0), '%', Icons.air, const Color(0xFF64D8CB), (_fanPercent / 100).clamp(0, 1)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 1 : 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: compact ? 3.5 : 2.1,
      ),
      itemBuilder: (context, index) => _buildMetricCard(cards[index]),
    );
  }

  Widget _buildMetricCard(_MetricData metric) {
    return _Panel(
      child: Row(
        children: [
          Icon(metric.icon, color: metric.color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(metric.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: metric.value,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 25, fontWeight: FontWeight.w700),
                    children: [TextSpan(text: ' ${metric.unit}', style: TextStyle(color: metric.color, fontSize: 13, fontWeight: FontWeight.w600))],
                  ),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(value: metric.progress, minHeight: 3, backgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(20), color: metric.color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    final maximum = _history.isEmpty ? 0 : _history.map((sample) => sample.temperature).reduce((a, b) => a > b ? a : b);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Sıcaklık geçmişi', 'Son 1 saat')),
              Text('Maks. ${maximum.toStringAsFixed(1)} °C', style: const TextStyle(color: Color(0xFFFFB454), fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 130, child: _history.isEmpty ? const Center(child: Text('Bridge metrikleri bekleniyor', style: TextStyle(color: Colors.white54, fontSize: 12))) : CustomPaint(painter: _HistoryPainter(_history, Theme.of(context).colorScheme.primary))),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Kontroller', 'Güvenli kullanıcı alanı ayarları'),
          const SizedBox(height: 20),
          _buildPresetRow(),
          const SizedBox(height: 14),
          _buildSliderControl('Fan Hızı', Icons.air, _fanValue, (value) => setState(() => _fanValue = value), const Color(0xFF64D8CB)),
          Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(20), height: 30),
          _buildSliderControl('AI İşlem Gücü', Icons.auto_awesome, _aiValue, (value) => setState(() => _aiValue = value), const Color(0xFF8FA7FF)),
        ],
      ),
    );
  }

  Widget _buildPresetRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _presetButton('Sessiz', Icons.volume_off_outlined, 25, 45, const Color(0xFF64D8CB)),
        _presetButton('Dengeli', Icons.tune, 50, 80, const Color(0xFFFFB454)),
        _presetButton('Performans', Icons.speed, 85, 100, const Color(0xFFFF7B7B)),
        _presetButton('Oyun', Icons.sports_esports_outlined, 75, 95, const Color(0xFFB995FF)),
        _presetButton('Manuel', Icons.edit_outlined, _fanValue, _aiValue, const Color(0xFF8FA7FF)),
        TextButton.icon(onPressed: _isSending ? null : _resetControls, icon: const Icon(Icons.restart_alt, size: 16), label: const Text('Sıfırla')),
        TextButton.icon(onPressed: () => _saveProfile('Manuel'), icon: const Icon(Icons.save_outlined, size: 16), label: const Text('Profili kaydet')),
      ],
    );
  }

  Widget _presetButton(String label, IconData icon, double fan, double ai, Color color) {
    return OutlinedButton.icon(
      onPressed: _isSending ? null : () => _applyPreset(label, fan, ai),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withAlpha(100))),
    );
  }

  Widget _buildSliderControl(String label, IconData icon, double value, ValueChanged<double> onChanged, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${value.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Uygula',
              onPressed: _isSending ? null : () => _sendCommand(label, value),
              icon: const Icon(Icons.check_circle_outline),
              color: color,
            ),
          ],
        ),
        Slider(value: value, min: 0, max: 100, divisions: 20, activeColor: color, onChanged: onChanged),
      ],
    );
  }

  Widget _buildSystemCard() {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Sistem durumu', 'Kontrol akışı'),
          const SizedBox(height: 20),
          _statusRow('Bridge', _isConnected ? 'Bağlı' : 'Bağlı değil', _isConnected),
          _statusRow('Güvenlik', _sharedKey.isEmpty ? 'Anahtar bekleniyor' : 'HMAC-SHA-256', _sharedKey.isNotEmpty),
          _statusRow('Model SHA-256', _modelDigest == 'unavailable' ? 'Bulunamadı' : (_modelDigest.length > 12 ? '${_modelDigest.substring(0, 12)}...' : _modelDigest), _modelDigest != 'unavailable' && _modelDigest != 'Kontrol edilmedi'),
          _statusRow('Uyarı eşiği', '${_temperatureLimit.round()} °C', _notificationsEnabled),
          _statusRow('Son sıcaklık', '${_cpuTemperature.toStringAsFixed(1)} °C', _cpuTemperature < _temperatureLimit || _cpuTemperature == 0),
          _statusRow('Son işlem', _lastAction, true),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withAlpha(8), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface.withAlpha(140), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_status, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(190), fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _isConnected ? null : _connectToBridge, icon: const Icon(Icons.refresh, size: 17), label: const Text('Yeniden bağlan')),
          const SizedBox(height: 18),
          _buildEvents(),
        ],
      ),
    );
  }

  Widget _buildEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Sistem olayları', 'Son 20 kayıt'),
        const SizedBox(height: 10),
        if (_events.isEmpty) const Text('Henüz olay yok', style: TextStyle(color: Colors.white54, fontSize: 12)),
        for (final event in _events.take(5)) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(event, style: const TextStyle(fontSize: 11, color: Colors.white60))),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140), fontSize: 12)),
      ],
    );
  }

  Widget _statusRow(String label, String value, bool healthy) {
    final color = healthy ? const Color(0xFF64D8CB) : const Color(0xFFFFB454);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 13))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.unit, this.icon, this.color, this.progress);
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double progress;
}

class _MetricSample {
  const _MetricSample(this.time, this.temperature);
  final DateTime time;
  final double temperature;
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.samples, this.color);
  final List<_MetricSample> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    final grid = Paint()..color = color.withAlpha(25)..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minimum = samples.map((sample) => sample.temperature).reduce((a, b) => a < b ? a : b);
    final maximum = samples.map((sample) => sample.temperature).reduce((a, b) => a > b ? a : b);
    final range = (maximum - minimum).abs() < 0.1 ? 1.0 : maximum - minimum;
    final path = Path();
    for (var index = 0; index < samples.length; index++) {
      final x = samples.length == 1 ? 0 : size.width * index / (samples.length - 1);
      final y = size.height - ((samples[index].temperature - minimum) / range * (size.height - 8)) - 4;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) => oldDelegate.samples != samples || oldDelegate.color != color;
}

class UpdateInfo {
  const UpdateInfo({required this.tag, required this.releaseUrl});
  final String tag;
  final String releaseUrl;
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
      ),
      child: child,
    );
  }
}
