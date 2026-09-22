import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
  static const _appVersion = '0.2.4';
  static const _checkFileUrl = 'https://raw.githubusercontent.com/lordkeremello45/HWcontrol2.0/main/updates/check.json';
  Socket? _socket;
  StreamIterator<String>? _responses;
  Process? _aiProcess;
  StreamIterator<String>? _aiResponses;
  bool _aiStarting = false;
  bool _aiSending = false;
  DateTime? _lastAiAnalysisAt;
  String _aiStatus = 'Yerel AI başlatılmadı';
  String _aiAnalysis = 'Gemma telemetry analizi bekleniyor';
  DateTime? _aiAnalysisTime;
  String _status = 'Bridge bekleniyor';
  String _lastAction = 'Henüz komut gönderilmedi';
  bool _isConnected = false;
  bool _isSending = false;
  bool _connecting = false;
  int _connectionGeneration = 0;
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;
  String _updateStatus = 'Güncellemeler kontrol edilmedi';
  double _fanValue = 50;
  double _aiValue = 80;
  double _temperatureLimit = 85;
  bool _notificationsEnabled = true;
  bool _polling = false;
  double _cpuUsage = 0;
  int _cpuCoreCount = 0;
  double _cpuFrequencyMHz = 0;
  double _cpuTemperature = 0;
  double _memoryUsage = 0;
  double _diskUsage = 0;
  double _gpuUsage = 0;
  double _gpuMemoryUsage = 0;
  double _gpuPowerWatts = 0;
  double _gpuPowerLimitWatts = 0;
  double _gpuCoreClockMHz = 0;
  double _gpuMemoryClockMHz = 0;
  String _gpuPState = 'N/A';
  double _gpuEncoderUsage = 0;
  double _gpuDecoderUsage = 0;
  List<double> _cpuPerCoreUsage = <double>[];
  double _fanPercent = 0;
  double _fanRpm = 0;
  String _gpuVendor = 'Bilinmiyor';
  String _sensorSource = 'Kontrol edilmedi';
  String _modelDigest = 'Kontrol edilmedi';
  bool _fanControlSupported = false;
  String _fanControlBackend = 'monitor-only';
  String _systemManufacturer = 'Bilinmiyor';
  String _systemModel = 'Bilinmiyor';
  String _biosVersion = 'Bilinmiyor';
  String _motherboardVendor = 'Bilinmiyor';
  String _motherboardModel = 'Bilinmiyor';
  String _cpuManufacturer = 'Bilinmiyor';
  String _cpuModel = 'Bilinmiyor';
  String _gpuModel = 'Bilinmiyor';
  String _gpuDriver = 'Bilinmiyor';
  String _hardwareDetectionStatus = 'Kontrol edilmedi';
  bool _gameModeEnabled = false;
  bool _gameDetected = false;
  String _gameProcessName = '';
  final List<_MetricSample> _history = <_MetricSample>[];
  final List<String> _events = <String>[];
  String _thermalStatus = 'Veri bekleniyor';
  bool _thermalAlertActive = false;
  Map<String, Map<String, double>> _profiles = {};
  bool _historyDirty = false;
  int _samplesSinceHistoryPersist = 0;
  static const _historySchema = 1;

  Future<File> get _telemetryHistoryFile async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}telemetry-history.json.gz');
  }

  String _fileSharedKey = '';

  String get _sharedKey {
    final environmentKey = Platform.environment['HWCONTROL_KEY'];
    if (environmentKey != null && environmentKey.isNotEmpty) return environmentKey;
    if (_fileSharedKey.isNotEmpty) return _fileSharedKey;
    return _compileTimeKey;
  }

  Future<void> _loadBridgeKey() async {
    final candidates = <String>[];
    if (Platform.isWindows) {
      final programData = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
      candidates.add('$programData${Platform.pathSeparator}HWControl${Platform.pathSeparator}bridge.key');
    } else if (Platform.isMacOS) {
      candidates.add('/Library/Application Support/HWControl/bridge.key');
    } else if (Platform.isLinux) {
      candidates.add('/var/lib/hwcontrol/bridge.key');
    }
    for (final path in candidates) {
      try {
        final key = (await File(path).readAsString()).trim();
        if (key.isNotEmpty) {
          _fileSharedKey = key;
          return;
        }
      } catch (_) {}
    }
  }

  int get _bridgePort => int.tryParse(Platform.environment['HWCONTROL_PORT'] ?? '8080') ?? 8080;

  String get _bridgeSocketPath {
    final configured = Platform.environment['HWCONTROL_SOCKET'];
    if (configured != null && configured.isNotEmpty) return configured;
    if (Platform.isMacOS) return '/Library/Application Support/HWControl/bridge.sock';
    return '/var/lib/hwcontrol/bridge.sock';
  }

  Future<Socket> _openBridgeSocket() {
    if (Platform.isLinux || Platform.isMacOS) {
      final address = InternetAddress(_bridgeSocketPath, type: InternetAddressType.unix);
      return Socket.connect(address, 0, timeout: const Duration(seconds: 3));
    }
    return Socket.connect('127.0.0.1', _bridgePort, timeout: const Duration(seconds: 3));
  }

  String _defaultModelPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return '$localAppData${Platform.pathSeparator}HWControl${Platform.pathSeparator}models${Platform.pathSeparator}gemma-3-1b-it-Q5_K_M.gguf';
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return '$home${Platform.pathSeparator}Library${Platform.pathSeparator}Application Support${Platform.pathSeparator}HWControl${Platform.pathSeparator}models${Platform.pathSeparator}gemma-3-1b-it-Q5_K_M.gguf';
      }
    } else if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_CACHE_HOME'];
      if (xdg != null && xdg.isNotEmpty) {
        return '$xdg${Platform.pathSeparator}HWControl${Platform.pathSeparator}models${Platform.pathSeparator}gemma-3-1b-it-Q5_K_M.gguf';
      }
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return '$home${Platform.pathSeparator}.cache${Platform.pathSeparator}HWControl${Platform.pathSeparator}models${Platform.pathSeparator}gemma-3-1b-it-Q5_K_M.gguf';
      }
    }
    return 'ai_core${Platform.pathSeparator}models${Platform.pathSeparator}gemma-3-1b-it-Q5_K_M.gguf';
  }

  Future<String?> _findAiEnginePath() async {
    final executable = File(Platform.resolvedExecutable);
    final executableDir = executable.parent.path;
    final binaryName = Platform.isWindows ? 'ai_engine.exe' : 'ai_engine';
    final candidates = <String>[
      '$executableDir${Platform.pathSeparator}$binaryName',
      '${Directory(executableDir).parent.path}${Platform.pathSeparator}$binaryName',
      '${Directory(Directory(executableDir).parent.path).parent.path}${Platform.pathSeparator}$binaryName',
      '${Directory.current.path}${Platform.pathSeparator}$binaryName',
      '${Directory.current.path}${Platform.pathSeparator}ai_core${Platform.pathSeparator}$binaryName',
    ];
    for (final candidate in candidates) {
      try {
        if (await File(candidate).exists()) return candidate;
      } catch (_) {}
    }
    return null;
  }

  String _aiNumber(dynamic value) {
    final number = value is num ? value.toDouble() : double.nan;
    return number.isFinite ? number.toStringAsFixed(3) : 'nan';
  }

  String _aiBool(dynamic value) => value == true ? '1' : '0';

  String _hexEncode(String value) {
    final bytes = utf8.encode(value);
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _buildAiTelemetryLine(Map<String, dynamic> data) {
    final cores = ((data['cpuPerCoreUsage'] as List?) ?? const <dynamic>[]).whereType<num>();
    double maxCore = double.nan;
    for (final value in cores) {
      final number = value.toDouble();
      if (number.isFinite && (!maxCore.isFinite || number > maxCore)) {
        maxCore = number;
      }
    }
    return <String>[
      'cpu_temp=${_aiNumber(data['cpuTemperature'])}',
      'cpu_load=${_aiNumber(data['cpuUsage'])}',
      'cpu_max_core=${maxCore.isFinite ? maxCore.toStringAsFixed(3) : 'nan'}',
      'cpu_freq=${_aiNumber(data['cpuFrequencyMHz'])}',
      'cpu_cores=${((data['cpuCoreCount'] as num?)?.toInt() ?? 0)}',
      'gpu_temp=${_aiNumber(data['gpuTemperature'])}',
      'gpu_load=${_aiNumber(data['gpuUsage'])}',
      'gpu_memory=${_aiNumber(data['gpuMemoryUsage'])}',
      'gpu_power=${_aiNumber(data['powerWatts'])}',
      'gpu_power_limit=${_aiNumber(data['gpuPowerLimitWatts'])}',
      'gpu_core_clock=${_aiNumber(data['gpuCoreClockMHz'])}',
      'gpu_memory_clock=${_aiNumber(data['gpuMemoryClockMHz'])}',
      'gpu_encoder=${_aiNumber(data['gpuEncoderUsage'])}',
      'gpu_decoder=${_aiNumber(data['gpuDecoderUsage'])}',
      'fan=${_aiNumber(data['fanPercent'])}',
      'fan_rpm=${_aiNumber(data['fanRpm'])}',
      'ram=${_aiNumber(data['memoryUsage'])}',
      'disk=${_aiNumber(data['diskUsage'])}',
      'game_mode=${_aiBool(data['gameModeEnabled'])}',
      'game_detected=${_aiBool(data['gameDetected'])}',
      'thermal_status_hex=${_hexEncode(_thermalStatus)}',
      'gpu_vendor_hex=${_hexEncode((data['gpuVendor'] as String?) ?? '')}',
      'gpu_name_hex=${_hexEncode((data['gpuModel'] as String?) ?? '')}',
      'game_process_hex=${_hexEncode((data['gameProcessName'] as String?) ?? '')}',
    ].join(' ');
  }

  Future<void> _ensureAiEngine() async {
    if (_aiProcess != null || _aiStarting) return;
    _aiStarting = true;
    try {
      final executablePath = await _findAiEnginePath();
      final modelPath = _defaultModelPath();
      if (executablePath == null) {
        if (mounted) setState(() => _aiStatus = 'ai_engine bulunamadı');
        return;
      }
      if (!await File(modelPath).exists()) {
        if (mounted) setState(() => _aiStatus = 'Gemma 3 1B modeli henüz hazır değil');
        return;
      }

      final environment = Map<String, String>.from(Platform.environment);
      environment['HWCONTROL_MODEL'] = modelPath;
      final process = await Process.start(executablePath, const ['--stdio'], environment: environment, runInShell: false);
      _aiProcess = process;
      _aiResponses = StreamIterator(process.stdout.transform(utf8.decoder).transform(const LineSplitter()));
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((_) {});
      process.exitCode.then((code) {
        if (_aiProcess == process) {
          _aiProcess = null;
          _aiResponses = null;
          if (mounted) setState(() => _aiStatus = code == 0 ? 'Yerel AI kapandı' : 'Yerel AI işlemi sonlandı');
        }
      });
      if (mounted) setState(() => _aiStatus = 'Gemma 3 1B yerel inference hazır');
    } catch (_) {
      _aiProcess = null;
      _aiResponses = null;
      if (mounted) setState(() => _aiStatus = 'Yerel AI başlatılamadı');
    } finally {
      _aiStarting = false;
    }
  }

  Future<void> _requestAiAnalysis(Map<String, dynamic> data, {bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastAiAnalysisAt != null && now.difference(_lastAiAnalysisAt!) < const Duration(seconds: 30)) return;
    if (_aiSending) return;
    _lastAiAnalysisAt = now;
    _aiSending = true;
    try {
      await _ensureAiEngine();
      final process = _aiProcess;
      final responses = _aiResponses;
      if (process == null || responses == null) return;

      process.stdin.writeln(_buildAiTelemetryLine(data));
      await process.stdin.flush();
      if (!await responses.moveNext().timeout(const Duration(seconds: 25))) {
        throw StateError('AI response timeout');
      }
      final response = responses.current;
      if (!response.startsWith('OK|')) {
        throw StateError(response);
      }
      final analysis = response.substring(3).trim();
      if (!mounted) return;
      setState(() {
        _aiAnalysis = analysis.isEmpty ? 'AI yanıt üretemedi' : analysis;
        _aiAnalysisTime = DateTime.now();
        _aiStatus = 'Gemma 3 1B inference aktif';
      });
    } catch (_) {
      try {
        _aiProcess?.kill();
      } catch (_) {}
      _aiProcess = null;
      _aiResponses = null;
      if (mounted) setState(() => _aiStatus = 'AI analizi başarısız');
    } finally {
      _aiSending = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // GUI I/O is deliberately serialized. No startup operation is allowed
    // to race another operation, and the metrics loop never overlaps itself.
    _runStartupSequence();
  }

  Future<void> _runStartupSequence() async {
    if (_polling) return;
    _polling = true;
    try {
      await _loadProfiles();
      await _loadTelemetryHistory();
      await _loadBridgeKey();
      if (!mounted) return;
      await _connectToBridge();
      if (!mounted) return;
      await _refreshSecurity();
      if (!mounted) return;
      await _checkForUpdateInternal();
      if (!mounted) return;
      while (mounted) {
        if (_isConnected) {
          await _refreshMetrics();
        } else {
          await _connectToBridge();
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    } finally {
      _polling = false;
    }
  }

  Future<File> get _profilesFile async => File('hwcontrol_profiles.json');

  Future<void> _loadProfiles() async {
    try {
      final file = await _profilesFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (!mounted) return;
      final profiles = <String, Map<String, double>>{};
      for (final entry in decoded.entries) {
        final values = entry.value as Map;
        profiles[entry.key] = {
          'fan': (values['fan'] as num).toDouble(),
          'ai': (values['ai'] as num).toDouble(),
        };
      }
      setState(() => _profiles = profiles);
    } catch (_) {
      _addEvent('Profil dosyası okunamadı');
    }
  }

  Future<void> _loadTelemetryHistory() async {
    try {
      final file = await _telemetryHistoryFile;
      if (!await file.exists()) return;
      final compressed = await file.readAsBytes();
      final decoded = ZLibCodec(gzip: true).decode(compressed);
      final root = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
      if (root['schema'] != _historySchema) return;
      final samples = root['samples'];
      if (samples is! List) return;
      final restored = <_MetricSample>[];
      for (final item in samples) {
        if (item is! Map) continue;
        final timestamp = DateTime.tryParse(item['timestamp'] as String? ?? '');
        if (timestamp == null) continue;
        double number(String key) => (item[key] as num?)?.toDouble() ?? double.nan;
        restored.add(_MetricSample(
          timestamp,
          number('cpuTemperature'), number('cpuUsage'), number('cpuFrequencyMHz'),
          number('gpuTemperature'), number('gpuUsage'), number('gpuCoreClockMHz'),
          number('gpuPowerWatts'), number('gpuMemoryUsage'), number('fanPercent'),
          number('fanRpm'), number('memoryUsage'), number('diskUsage'),
        ));
      }
      if (restored.length > 720) restored.removeRange(0, restored.length - 720);
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(restored);
      });
      _addEvent('Sıkıştırılmış telemetry geçmişi yüklendi');
    } catch (_) {
      // Corrupt or incompatible history must never block application startup.
      _addEvent('Telemetry geçmişi okunamadı; yeni geçmiş başlatıldı');
    }
  }

  Future<void> _persistTelemetryHistory() async {
    if (!_historyDirty) return;
    try {
      final file = await _telemetryHistoryFile;
      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        'schema': _historySchema,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'encoding': 'gzip+json',
        'samples': _history.map((sample) => <String, dynamic>{
          'timestamp': sample.time.toUtc().toIso8601String(),
          'cpuTemperature': sample.cpuTemperature,
          'cpuUsage': sample.cpuUsage,
          'cpuFrequencyMHz': sample.cpuFrequencyMHz,
          'gpuTemperature': sample.gpuTemperature,
          'gpuUsage': sample.gpuUsage,
          'gpuCoreClockMHz': sample.gpuCoreClockMHz,
          'gpuPowerWatts': sample.gpuPowerWatts,
          'gpuMemoryUsage': sample.gpuMemoryUsage,
          'fanPercent': sample.fanPercent,
          'fanRpm': sample.fanRpm,
          'memoryUsage': sample.memoryUsage,
          'diskUsage': sample.diskUsage,
        }).toList(growable: false),
      };
      final json = utf8.encode(jsonEncode(payload));
      final compressed = ZLibCodec(gzip: true, level: 6).encode(json);
      final temporary = File('undefined.tmp');
      await temporary.writeAsBytes(compressed, flush: true);
      await temporary.rename(file.path);
      _historyDirty = false;
      _samplesSinceHistoryPersist = 0;
    } catch (_) {
      // Persistence is best-effort; telemetry collection must continue.
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

  Future<void> _exportDiagnosticReport() async {
    if (!_isConnected) {
      if (mounted) setState(() => _status = 'Tanılama raporu için bridge bağlantısı gerekli');
      return;
    }
    try {
      final diagnostics = await _requestBridgeData('Get Diagnostics');
      final status = await _requestBridgeData('Get Status');
      if (diagnostics == null || status == null) throw StateError('Bridge tanılama verisi alınamadı');
      final report = <String, dynamic>{
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'applicationVersion': _appVersion,
        'platform': Platform.operatingSystem,
        'architecture': Platform.operatingSystemVersion,
        'diagnostics': diagnostics,
        'status': status,
        'events': List<String>.from(_events),
        'telemetrySamples': _history.map((sample) => {'timestamp': sample.time.toUtc().toIso8601String(), 'cpuTemperature': sample.cpuTemperature, 'cpuUsage': sample.cpuUsage, 'cpuFrequencyMHz': sample.cpuFrequencyMHz, 'gpuTemperature': sample.gpuTemperature, 'gpuUsage': sample.gpuUsage, 'gpuCoreClockMHz': sample.gpuCoreClockMHz, 'gpuPowerWatts': sample.gpuPowerWatts, 'gpuMemoryUsage': sample.gpuMemoryUsage, 'fanPercent': sample.fanPercent, 'fanRpm': sample.fanRpm, 'memoryUsage': sample.memoryUsage, 'diskUsage': sample.diskUsage}).toList(growable: false),
        'thermalStatus': _thermalStatus,
      };
      final readme = '''HWControl Diagnostic Report

This report was generated locally by HWControl. No data was uploaded automatically.
Authentication keys, tokens, passwords and signing credentials are intentionally excluded.
Attach this archive to a support issue only after reviewing it for personal information.
''';
      final archive = Archive();
      final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(report));
      archive.addFile(ArchiveFile.bytes('diagnostics.json', jsonBytes));
      archive.addFile(ArchiveFile.bytes('README.txt', utf8.encode(readme)));
      final zipBytes = ZipEncoder().encode(archive);
      final downloads = await getDownloadsDirectory();
      final directory = downloads ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${directory.path}${Platform.pathSeparator}HWControl-Diagnostic-Report-$stamp.zip');
      await file.writeAsBytes(zipBytes, flush: true);
      if (!mounted) return;
      setState(() => _status = 'Tanılama raporu oluşturuldu: ${file.path}');
      _addEvent('Tanılama raporu dışa aktarıldı');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Tanılama raporu oluşturulamadı');
      _addEvent('Tanılama raporu hatası: $error');
    }
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

  String _evaluateThermalStatus({required double cpuTemperature, required double cpuUsage, required double cpuFrequencyMHz, required double gpuTemperature, required double gpuUsage, required double gpuCoreClockMHz}) {
    if (_history.length < 3) return 'Veri yetersiz';
    final previous = _history[_history.length - 2];
    final current = _history.last;
    final cpuClockDrop = previous.cpuFrequencyMHz > 0 && cpuFrequencyMHz > 0 ? (previous.cpuFrequencyMHz - cpuFrequencyMHz) / previous.cpuFrequencyMHz : 0.0;
    final gpuClockDrop = previous.gpuCoreClockMHz > 0 && gpuCoreClockMHz > 0 ? (previous.gpuCoreClockMHz - gpuCoreClockMHz) / previous.gpuCoreClockMHz : 0.0;
    final cpuSuspected = cpuTemperature >= 85 && cpuUsage >= 85 && cpuClockDrop >= 0.15;
    final gpuSuspected = gpuTemperature >= 80 && gpuUsage >= 80 && gpuClockDrop >= 0.15;
    if (cpuSuspected || gpuSuspected) return cpuSuspected && gpuSuspected ? 'CPU + GPU termal throttling şüphesi' : cpuSuspected ? 'CPU termal throttling şüphesi' : 'GPU termal throttling şüphesi';
    if (cpuTemperature >= 90 || gpuTemperature >= 88) return 'Yüksek sıcaklık';
    if (current.cpuTemperature > 0 && cpuTemperature - previous.cpuTemperature >= 5) return 'Hızlı CPU sıcaklık artışı';
    return 'Normal';
  }

  String _csvEscape(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\\n')) return value;
    return '"' + value.replaceAll('"', '""') + '"';
  }

  Future<void> _exportTelemetryHistory() async {
    try {
      final directory = await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File(directory.path + Platform.pathSeparator + 'HWControl-Telemetry-' + stamp + '.csv');
      final buffer = StringBuffer('timestamp,cpu_temperature,cpu_usage,cpu_frequency_mhz,gpu_temperature,gpu_usage,gpu_core_clock_mhz,gpu_power_watts,gpu_memory_usage,fan_percent,fan_rpm,memory_usage,disk_usage,thermal_status\\n');
      for (final sample in _history) {
        buffer.writeln([sample.time.toUtc().toIso8601String(), sample.cpuTemperature, sample.cpuUsage, sample.cpuFrequencyMHz, sample.gpuTemperature, sample.gpuUsage, sample.gpuCoreClockMHz, sample.gpuPowerWatts, sample.gpuMemoryUsage, sample.fanPercent, sample.fanRpm, sample.memoryUsage, sample.diskUsage, _csvEscape(_thermalStatus)].join(','));
      }
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      setState(() => _status = 'Telemetry CSV oluşturuldu: ' + file.path);
      _addEvent('Telemetry geçmişi dışa aktarıldı');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Telemetry dışa aktarılamadı');
      _addEvent('Telemetry export hatası: ' + error.toString());
    }
  }
  Future<void> _refreshMetrics() async {
    if (!_isConnected || _isSending) return;
    final data = await _requestBridgeData('Get Status');
    if (!mounted || data == null) return;
    final temperature = (data['cpuTemperature'] as num?)?.toDouble() ?? 0;
    final thresholdExceeded = _notificationsEnabled && temperature >= _temperatureLimit;
    setState(() {
      _cpuUsage = (data['cpuUsage'] as num?)?.toDouble() ?? 0;
      _cpuCoreCount = (data['cpuCoreCount'] as num?)?.toInt() ?? 0;
      _cpuFrequencyMHz = (data['cpuFrequencyMHz'] as num?)?.toDouble() ?? 0;
      _cpuTemperature = temperature;
      _memoryUsage = (data['memoryUsage'] as num?)?.toDouble() ?? 0;
      _diskUsage = (data['diskUsage'] as num?)?.toDouble() ?? 0;
      _gpuUsage = (data['gpuUsage'] as num?)?.toDouble() ?? 0;
      _gpuMemoryUsage = (data['gpuMemoryUsage'] as num?)?.toDouble() ?? 0;
      _gpuPowerWatts = (data['powerWatts'] as num?)?.toDouble() ?? 0;
      _gpuPowerLimitWatts = (data['gpuPowerLimitWatts'] as num?)?.toDouble() ?? 0;
      _gpuCoreClockMHz = (data['gpuCoreClockMHz'] as num?)?.toDouble() ?? 0;
      _gpuMemoryClockMHz = (data['gpuMemoryClockMHz'] as num?)?.toDouble() ?? 0;
      _gpuPState = data['gpuPState'] as String? ?? 'N/A';
      _gpuEncoderUsage = (data['gpuEncoderUsage'] as num?)?.toDouble() ?? 0;
      _gpuDecoderUsage = (data['gpuDecoderUsage'] as num?)?.toDouble() ?? 0;
      _cpuPerCoreUsage = ((data['cpuPerCoreUsage'] as List?) ?? const <dynamic>[]).whereType<num>().map((value) => value.toDouble()).toList(growable: false);
      _fanPercent = (data['fanPercent'] as num?)?.toDouble() ?? 0;
      _fanRpm = (data['fanRpm'] as num?)?.toDouble() ?? 0;
      _gpuVendor = data['gpuVendor'] as String? ?? 'Bilinmiyor';
      _sensorSource = data['sensorSource'] as String? ?? 'Bilinmiyor';
      _fanControlSupported = data['fanControlSupported'] as bool? ?? false;
      _fanControlBackend = data['fanControlBackend'] as String? ?? 'monitor-only';
      _systemManufacturer = data['systemManufacturer'] as String? ?? 'Bilinmiyor';
      _systemModel = data['systemModel'] as String? ?? 'Bilinmiyor';
      _biosVersion = data['biosVersion'] as String? ?? 'Bilinmiyor';
      _motherboardVendor = data['motherboardVendor'] as String? ?? 'Bilinmiyor';
      _motherboardModel = data['motherboardModel'] as String? ?? 'Bilinmiyor';
      _cpuManufacturer = data['cpuManufacturer'] as String? ?? 'Bilinmiyor';
      _cpuModel = data['cpuModel'] as String? ?? 'Bilinmiyor';
      _gpuModel = data['gpuModel'] as String? ?? 'Bilinmiyor';
      _gpuDriver = data['gpuDriver'] as String? ?? 'Bilinmiyor';
      _hardwareDetectionStatus = data['detectionStatus'] as String? ?? 'partial';
      _gameModeEnabled = data['gameModeEnabled'] as bool? ?? false;
      _gameDetected = data['gameDetected'] as bool? ?? false;
      _gameProcessName = data['gameProcessName'] as String? ?? '';
      _history.add(_MetricSample(DateTime.now(), temperature, _cpuUsage, _cpuFrequencyMHz, (data['gpuTemperature'] as num?)?.toDouble() ?? 0, _gpuUsage, _gpuCoreClockMHz, _gpuPowerWatts, _gpuMemoryUsage, _fanPercent, _fanRpm, _memoryUsage, _diskUsage));
      if (_history.length > 720) _history.removeAt(0);
      _historyDirty = true;
      _samplesSinceHistoryPersist++;
      _thermalStatus = _evaluateThermalStatus(
        cpuTemperature: temperature,
        cpuUsage: _cpuUsage,
        cpuFrequencyMHz: _cpuFrequencyMHz,
        gpuTemperature: _history.last.gpuTemperature,
        gpuUsage: _gpuUsage,
        gpuCoreClockMHz: _gpuCoreClockMHz,
      );
      final thermalAlert = _thermalStatus.contains('şüphesi') || _thermalStatus == 'Yüksek sıcaklık';
      if (thermalAlert && !_thermalAlertActive) {
        _events.insert(0, DateTime.now().toLocal().toString().substring(11, 19) + '  ' + _thermalStatus);
        if (_events.length > 20) _events.removeLast();
      }
      _thermalAlertActive = thermalAlert;
      if (thresholdExceeded) {
        _status = 'Sıcaklık uyarısı: ${temperature.toStringAsFixed(1)} °C';
      } else if (thermalAlert) {
        _status = _thermalStatus;
      }
    });
    if (thresholdExceeded) _addEvent('CPU sıcaklığı eşik üstünde');
    if (_samplesSinceHistoryPersist >= 12) unawaited(_persistTelemetryHistory());
    unawaited(_requestAiAnalysis(data));
  }

  Future<void> _refreshSecurity() async {
    if (!_isConnected || _isSending) return;
    final data = await _requestBridgeData('Get Security');
    if (!mounted || data == null) return;
    setState(() => _modelDigest = data['modelSha256'] as String? ?? 'unavailable');
  }

  Future<void> _checkForUpdate() async {
    if (_polling) return;
    await _checkForUpdateInternal();
  }

  Future<void> _checkForUpdateInternal() async {
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
    if (_connecting || _isConnected) return;
    final generation = ++_connectionGeneration;
    _connecting = true;
    try {
      final socket = await _openBridgeSocket();
      if (generation != _connectionGeneration || !mounted) {
        socket.destroy();
        return;
      }
      _socket?.destroy();
      _responses?.cancel();
      _socket = socket;
      _responses = StreamIterator(socket.map(utf8.decode).transform(const LineSplitter()));
      socket.done.whenComplete(() {
        if (!mounted || generation != _connectionGeneration) return;
        setState(() {
          _isConnected = false;
          _status = 'Bridge bağlantısı kesildi';
        });
      });
      if (!mounted || generation != _connectionGeneration) return;
      setState(() {
        _isConnected = true;
        _status = 'Bridge aktif';
      });
      _addEvent('Bridge bağlantısı kuruldu');
    } catch (_) {
      if (!mounted || generation != _connectionGeneration) return;
      setState(() {
        _isConnected = false;
        _status = 'Bridge bulunamadı';
      });
    } finally {
      if (generation == _connectionGeneration) _connecting = false;
    }
  }

  Future<bool> _sendCommand(String action, double value) async {
    if ((action == 'Fan Hızı' || action == 'AI İşlem Gücü') && !_fanControlSupported) {
      if (mounted) setState(() => _status = 'Donanım kontrol backend\'i bu platformda kullanılabilir değil');
      return false;
    }
    final socket = _socket;
    if (!_isConnected || socket == null) {
      setState(() => _status = 'Önce bridge servisini başlatın');
      return false;
    }
    if (_isSending) return false;
    if (_sharedKey.isEmpty) {
      setState(() => _status = 'HWCONTROL_KEY ayarlı değil');
      return false;
    }

    setState(() => _isSending = true);
    try {
      final payload = '$action\n${value.toStringAsFixed(6)}';
      final auth = Hmac(sha256, utf8.encode(_sharedKey)).convert(utf8.encode(payload)).toString();
      socket.write('${jsonEncode({
        'action': action,
        'value': value,
        'auth': auth,
      })}\n');

      final responses = _responses;
      if (responses == null || !await responses.moveNext().timeout(const Duration(seconds: 3))) {
        throw StateError('Bridge response missing');
      }
      final response = jsonDecode(responses.current) as Map<String, dynamic>;
      if (!mounted) return false;
      setState(() {
        _status = response['message'] as String? ?? 'Yanıt alındı';
        _lastAction = '$action  •  %${value.round()}';
      });
    } catch (_) {
      if (!mounted) return false;
      setState(() => _status = 'Bridge yanıt vermedi');
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    return true;
  }

  Future<void> _playGameModeSound(bool enabled) async {
    // Short, locally synthesized gamer-style UI sound. No external audio
    // asset or network request is required, and it only runs after a
    // successful Game Mode toggle.
    final sampleRate = 11025;
    final durationMs = enabled ? 220 : 180;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final bytes = BytesBuilder(copy: false);

    void write16(int value) {
      bytes.addByte(value & 0xff);
      bytes.addByte((value >> 8) & 0xff);
    }

    void writeAscii(String value) {
      bytes.add(value.codeUnits);
    }

    final dataSize = sampleCount;
    final fileSize = 36 + dataSize;
    writeAscii('RIFF');
    write16(fileSize & 0xffff);
    write16((fileSize >> 16) & 0xffff);
    writeAscii('WAVEfmt ');
    write16(16);
    write16(1);
    write16(1);
    write16(sampleRate & 0xffff);
    write16((sampleRate >> 16) & 0xffff);
    write16(sampleRate & 0xffff);
    write16((sampleRate >> 16) & 0xffff);
    write16(1);
    write16(8);
    writeAscii('data');
    write16(dataSize & 0xffff);
    write16((dataSize >> 16) & 0xffff);

    final pcm = Uint8List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final x = i / sampleCount;
      final frequency = enabled ? 540 + 920 * x : 1050 - 680 * x;
      final attack = (x / (enabled ? 0.055 : 0.06)).clamp(0.0, 1.0);
      final release = ((1.0 - x) / (enabled ? 0.23 : 0.25)).clamp(0.0, 1.0);
      final envelope = attack * release;
      final primary = math.sin(2 * math.pi * frequency * t);
      final harmonic = math.sin(2 * math.pi * frequency * 2 * t);
      final sample = ((primary * 0.72 + harmonic * 0.12) * envelope * 0.65).clamp(-1.0, 1.0);
      pcm[i] = ((sample + 1.0) * 127.5).round();
    }
    bytes.add(pcm);

    try {
      final player = AudioPlayer();
      await player.play(BytesSource(bytes.takeBytes(), mimeType: 'audio/wav'), volume: 0.55);
      await Future<void>.delayed(Duration(milliseconds: durationMs + 40));
      await player.dispose();
    } catch (_) {
      // Audio feedback is optional; Game Mode must still work silently.
    }
  }

  Future<void> _applyPreset(String name, double fan, double ai) async {
    if (_isSending) return;
    setState(() {
      _fanValue = fan;
      _aiValue = ai;
      _lastAction = '$name profili hazırlanıyor';
    });
    final savedProfile = _profiles[name];
    if (savedProfile != null) {
      fan = savedProfile['fan'] ?? fan;
      ai = savedProfile['ai'] ?? ai;
      setState(() { _fanValue = fan; _aiValue = ai; });
    }
    await _sendCommand('Fan Hızı', fan);
    if (!mounted || !_isConnected) return;
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
    // Do not block Flutter disposal; the latest snapshot is already persisted
    // periodically during normal operation.
    if (_historyDirty) unawaited(_persistTelemetryHistory());
    _connectionGeneration++;
    _responses?.cancel();
    _socket?.destroy();
    _aiResponses?.cancel();
    _aiProcess?.kill();
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
                      _buildAdvancedTelemetryCard(),
                      const SizedBox(height: 18),
                      _buildAiAnalysisCard(),
                      const SizedBox(height: 18),
                      _buildHardwareIdentityCard(),
                      const SizedBox(height: 18),
                      _buildGameModeCard(),
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
      _MetricData('Fan', _fanRpm > 0 ? _fanRpm.toStringAsFixed(0) : _fanPercent.toStringAsFixed(0), _fanRpm > 0 ? 'RPM' : '%', Icons.air, const Color(0xFF64D8CB), (_fanRpm > 0 ? _fanRpm / 3000 : _fanPercent / 100).clamp(0, 1)),
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
    final maximum = _history.isEmpty ? 0 : _history.map((sample) => sample.cpuTemperature).reduce((a, b) => a > b ? a : b);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Telemetry geçmişi', 'Son 1 saat • 5 saniyelik örnekleme')),
              Text('Maks. CPU ' + maximum.toStringAsFixed(1) + ' °C', style: const TextStyle(color: Color(0xFFFFB454), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              IconButton(tooltip: 'CSV dışa aktar', onPressed: _history.isEmpty ? null : _exportTelemetryHistory, icon: const Icon(Icons.download_outlined, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Termal durum: ' + _thermalStatus, style: TextStyle(fontSize: 11, color: _thermalAlertActive ? const Color(0xFFFFB454) : Theme.of(context).colorScheme.onSurface.withAlpha(140))),
          const SizedBox(height: 14),
          if (_history.isEmpty)
            const SizedBox(height: 130, child: Center(child: Text('Bridge metrikleri bekleniyor', style: TextStyle(color: Colors.white54, fontSize: 12))))
          else ...[
            SizedBox(height: 90, child: CustomPaint(painter: _HistoryPainter(_history, Theme.of(context).colorScheme.primary, (sample) => sample.cpuTemperature))),
            const SizedBox(height: 8),
            SizedBox(height: 90, child: CustomPaint(painter: _HistoryPainter(_history, const Color(0xFFFF8C69), (sample) => sample.gpuTemperature))),
            const SizedBox(height: 8),
            SizedBox(height: 90, child: CustomPaint(painter: _HistoryPainter(_history, const Color(0xFF8FA7FF), (sample) => sample.cpuUsage))),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedTelemetryCard() {
    final hasGpuTelemetry = _gpuVendor != 'Bilinmiyor' && (_gpuUsage > 0 || _gpuPowerWatts > 0 || _gpuCoreClockMHz > 0);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Advanced Telemetry', 'GPU yükü, VRAM, güç, saat hızları ve CPU çekirdekleri'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _telemetryChip('GPU', '${_gpuUsage.toStringAsFixed(0)}%'),
              _telemetryChip('VRAM', '${_gpuMemoryUsage.toStringAsFixed(0)}%'),
              _telemetryChip('GPU güç', '${_gpuPowerWatts.toStringAsFixed(1)} W'),
              _telemetryChip('Güç limiti', _gpuPowerLimitWatts > 0 ? '${_gpuPowerLimitWatts.toStringAsFixed(1)} W' : 'N/A'),
              _telemetryChip('Core clock', _gpuCoreClockMHz > 0 ? '${_gpuCoreClockMHz.toStringAsFixed(0)} MHz' : 'N/A'),
              _telemetryChip('Memory clock', _gpuMemoryClockMHz > 0 ? '${_gpuMemoryClockMHz.toStringAsFixed(0)} MHz' : 'N/A'),
              _telemetryChip('P-State', _gpuPState),
              _telemetryChip('Encoder', '${_gpuEncoderUsage.toStringAsFixed(0)}%'),
              _telemetryChip('Decoder', '${_gpuDecoderUsage.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 16),
          if (hasGpuTelemetry)
            LinearProgressIndicator(value: (_gpuPowerLimitWatts > 0 ? _gpuPowerWatts / _gpuPowerLimitWatts : _gpuUsage / 100).clamp(0, 1), minHeight: 4)
          else
            const Text('GPU gelişmiş telemetrisi sürücü/backend desteğine bağlıdır.', style: TextStyle(fontSize: 12)),
          if (_cpuPerCoreUsage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('CPU çekirdek yükü', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _cpuPerCoreUsage.length; i++)
                  SizedBox(width: 42, child: Column(children: [
                    Text('C${i + 1}', style: const TextStyle(fontSize: 9)),
                    const SizedBox(height: 3),
                    LinearProgressIndicator(value: (_cpuPerCoreUsage[i] / 100).clamp(0, 1), minHeight: 4),
                    const SizedBox(height: 2),
                    Text('${_cpuPerCoreUsage[i].round()}%', style: const TextStyle(fontSize: 9)),
                  ])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _telemetryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
        color: Theme.of(context).colorScheme.onSurface.withAlpha(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withAlpha(130))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisCard() {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20),
              const SizedBox(width: 10),
              Expanded(child: _sectionTitle('Local AI Analysis', 'Gerçek telemetry üzerinde yerel Gemma yorumu')),
              OutlinedButton.icon(
                onPressed: _aiSending ? null : () async {
                  final data = await _requestBridgeData('Get Status');
                  if (data != null) unawaited(_requestAiAnalysis(data, force: true));
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Yenile'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.onSurface.withAlpha(8),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
            ),
            child: Text(
              _aiAnalysis,
              style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 7, color: _aiProcess != null ? const Color(0xFF64D8CB) : const Color(0xFFFFB454)),
              const SizedBox(width: 8),
              Expanded(child: Text(_aiAnalysisTime == null ? _aiStatus : '$_aiStatus • ${_aiAnalysisTime!.toLocal().toString().substring(11, 19)}', style: const TextStyle(fontSize: 11))),
              const SizedBox(width: 8),
              const Text('LLM kontrol yetkisi yok', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareIdentityCard() {
    final detected = _hardwareDetectionStatus == 'ok';
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Donanım tanıma', 'PC, anakart, CPU ve GPU kimliği'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _hardwareIdentityTile(Icons.computer_outlined, 'PC', '$_systemManufacturer $_systemModel'),
              _hardwareIdentityTile(Icons.developer_board_outlined, 'Anakart', '$_motherboardVendor $_motherboardModel'),
              _hardwareIdentityTile(Icons.memory_outlined, 'CPU', '$_cpuManufacturer $_cpuModel'),
              _hardwareIdentityTile(Icons.videogame_asset_outlined, 'GPU', '$_gpuVendor • $_gpuModel'),
              _hardwareIdentityTile(Icons.dns_outlined, 'BIOS', _biosVersion),
              _hardwareIdentityTile(Icons.drive_file_rename_outline, 'GPU sürücüsü', _gpuDriver),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: detected ? const Color(0xFF64D8CB) : const Color(0xFFFFB454)),
              const SizedBox(width: 8),
              Text('Tanılama: $_hardwareDetectionStatus • Seri numaraları rapora dahil edilmez', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hardwareIdentityTile(IconData icon, String label, String value) {
    final text = value.trim().isEmpty ? 'Bilinmiyor' : value.trim();
    return SizedBox(
      width: 360,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(140))),
                  const SizedBox(height: 3),
                  Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeCard() {
    final active = _gameModeEnabled && _gameDetected;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.primary.withAlpha(18)), child: Icon(Icons.sports_esports_outlined, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle('Game Mode', 'Oyun çalışırken otomatik algılama ve oyun odaklı izleme'),
            const SizedBox(height: 8),
            Text(_gameDetected ? 'Algılanan oyun: ${_gameProcessName.isEmpty ? 'bilinmeyen işlem' : _gameProcessName}' : (_gameModeEnabled ? 'Game Mode hazır — oyun bekleniyor' : 'Game Mode kapalı'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(170))),
            const SizedBox(height: 4),
            Text(active ? 'Aktif • oyun süreci izleniyor' : 'Donanım kontrolü mevcut değilse fan/clock değişikliği yapılmaz', style: TextStyle(fontSize: 11, color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withAlpha(130))),
          ])),
          Switch(value: _gameModeEnabled, onChanged: _isSending ? null : (enabled) async {
            final success = await _sendCommand('Set Game Mode', enabled ? 100 : 0);
            if (!mounted) return;
            if (success) {
              setState(() => _gameModeEnabled = enabled);
              await _playGameModeSound(enabled);
              if (mounted) _addEvent(enabled ? 'Game Mode etkinleştirildi' : 'Game Mode devre dışı bırakıldı');
            }
          }),
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
        if (!_fanControlSupported) const Text('Donanım kontrolü: yalnızca izleme', style: TextStyle(fontSize: 12)),
        _presetButton('Sessiz', Icons.volume_off_outlined, 25, 45, const Color(0xFF64D8CB)),
        _presetButton('Dengeli', Icons.tune, 50, 80, const Color(0xFFFFB454)),
        _presetButton('Performans', Icons.speed, 85, 100, const Color(0xFFFF7B7B)),
        _presetButton('Oyun', Icons.sports_esports_outlined, 75, 95, const Color(0xFFB995FF)),
        _presetButton('Manuel', Icons.edit_outlined, _fanValue, _aiValue, const Color(0xFF8FA7FF)),
        TextButton.icon(onPressed: _isSending || !_fanControlSupported ? null : _resetControls, icon: const Icon(Icons.restart_alt, size: 16), label: const Text('Sıfırla')),
        TextButton.icon(onPressed: () => _saveProfile('Manuel'), icon: const Icon(Icons.save_outlined, size: 16), label: const Text('Profili kaydet')),
      ],
    );
  }

  Widget _presetButton(String label, IconData icon, double fan, double ai, Color color) {
    return OutlinedButton.icon(
      onPressed: _isSending || !_fanControlSupported ? null : () => _applyPreset(label, fan, ai),
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
              onPressed: _isSending || !_fanControlSupported ? null : () => _sendCommand(label, value),
              icon: const Icon(Icons.check_circle_outline),
              color: color,
            ),
          ],
        ),
        Slider(value: value, min: 0, max: 100, divisions: 20, activeColor: color, onChanged: _fanControlSupported ? onChanged : null),
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
          _statusRow('CPU', _cpuCoreCount > 0 ? '$_cpuCoreCount çekirdek • ${_cpuFrequencyMHz.toStringAsFixed(0)} MHz' : 'Bilinmiyor', _cpuCoreCount > 0),
          _statusRow('GPU adaptörü', _gpuVendor, _gpuVendor != 'Bilinmiyor'),
          _statusRow('Sensör kaynağı', _sensorSource, _sensorSource != 'Kontrol edilmedi'),
          _statusRow('Fan kontrolü', _fanControlSupported ? _fanControlBackend : 'Yalnızca izleme', _fanControlSupported),
          _statusRow('Uyarı eşiği', '${_temperatureLimit.round()} °C', _notificationsEnabled),
          _statusRow('Son sıcaklık', '${_cpuTemperature.toStringAsFixed(1)} °C', _cpuTemperature < _temperatureLimit || _cpuTemperature == 0),
          _statusRow('Termal durum', _thermalStatus, !_thermalAlertActive),
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(onPressed: _isConnected ? null : _connectToBridge, icon: const Icon(Icons.refresh, size: 17), label: const Text('Yeniden bağlan')),
              OutlinedButton.icon(onPressed: _isConnected ? _exportDiagnosticReport : null, icon: const Icon(Icons.archive_outlined, size: 17), label: const Text('Hata raporu oluştur')),
            ],
          ),
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
  const _MetricSample(this.time, this.cpuTemperature, this.cpuUsage, this.cpuFrequencyMHz, this.gpuTemperature, this.gpuUsage, this.gpuCoreClockMHz, this.gpuPowerWatts, this.gpuMemoryUsage, this.fanPercent, this.fanRpm, this.memoryUsage, this.diskUsage);
  final DateTime time;
  final double cpuTemperature;
  final double cpuUsage;
  final double cpuFrequencyMHz;
  final double gpuTemperature;
  final double gpuUsage;
  final double gpuCoreClockMHz;
  final double gpuPowerWatts;
  final double gpuMemoryUsage;
  final double fanPercent;
  final double fanRpm;
  final double memoryUsage;
  final double diskUsage;
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.samples, this.color, this.selector);
  final List<_MetricSample> samples;
  final Color color;
  final double Function(_MetricSample) selector;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final line = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    final grid = Paint()..color = color.withAlpha(25)..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final values = samples.map(selector).where((value) => value.isFinite).toList(growable: false);
    if (values.isEmpty) return;
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final range = (maximum - minimum).abs() < 0.1 ? 1.0 : maximum - minimum;
    final start = samples.first.time;
    final end = samples.last.time;
    final duration = end.difference(start).inMilliseconds.toDouble();
    final path = Path();
    var started = false;
    for (var index = 0; index < samples.length; index++) {
      final value = selector(samples[index]);
      if (!value.isFinite) continue;
      final x = duration <= 0 ? (samples.length == 1 ? 0.0 : size.width * index / (samples.length - 1)) : size.width * samples[index].time.difference(start).inMilliseconds / duration;
      final y = (size.height - ((value - minimum) / range * (size.height - 8)) - 4).toDouble();
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (started) canvas.drawPath(path, line);
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