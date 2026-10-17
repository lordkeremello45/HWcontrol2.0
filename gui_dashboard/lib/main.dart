import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'diagnostics.dart';
import 'setup_wizard.dart';
import 'fan_curve.dart';
import 'fan_channels.dart';
import 'benchmark.dart';
import 'automation_rules.dart';
import 'audio_controller_studio.dart';
import 'services/ai/model_manager.dart';
import 'user_data_store.dart';
import 'game_profile.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_map.dart';
import 'welcome_screen.dart';
import 'services/language_service.dart';
import 'services/localization_style_service.dart';
import 'services/audio/piper_tts_service.dart';
import 'security/authenticity_guard.dart';

void main() {
  final diagnostics = HWControlDiagnostics.instance;

  FlutterError.onError = (details) {
    unawaited(
      diagnostics.reportError(
        details.exception,
        details.stack ?? StackTrace.current,
        event: 'flutter_framework_error',
      ),
    );
    FlutterError.presentError(details);
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      diagnostics.reportError(
        error,
        stack,
        event: 'uncaught_async_error',
      ),
    );
    return false;
  };

  runApp(const HWControlApp());
}

class HWControlApp extends StatefulWidget {
  const HWControlApp({super.key});

  @override
  State<HWControlApp> createState() => _HWControlAppState();
}

class _HWControlAppState extends State<HWControlApp> {
  bool _darkMode = true;
  bool _animationsEnabled = true;
  bool _showWelcome = true;
  bool _welcomeSeen = false;
  bool _showSetupWizard = false;
  bool _setupWizardCompleted = false;
  final HWControlUserDataStore _userData = HWControlUserDataStore();
  Map<String, String> _welcomeTranslations = const <String, String>{};
  String _welcomeLocale = 'en-US';

  @override
  void initState() {
    super.initState();
    _loadUiPreferences();
    _loadWelcomeLocalization();
  }

  Future<void> _loadWelcomeLocalization() async {
    try {
      final settings = await _userData.readSettings();
      final savedLocale = settings['language'] as String?;
      final setupCompleted = settings['setupWizardCompleted'] == true;
      final style = settings['languageStyle'] == HWControlLocalizationStyleService.literary
          ? HWControlLocalizationStyleService.literary
          : HWControlLocalizationStyleService.standard;
      final locale = HWControlLanguageService.resolveLocale(
        savedLocale: savedLocale,
        supportedCodes: AppLocalizations.supportedLocales.map(localeTag),
      );
      final baseTranslations =
          lookupAppLocalizations(localeFromTag(locale)).toStringMap();
      final translations = await HWControlLocalizationStyleService.applyStyle(
        localeCode: locale,
        style: style,
        translations: baseTranslations,
      );
      if (!mounted) return;
      setState(() {
        _welcomeLocale = locale;
        _welcomeTranslations = translations;
        _setupWizardCompleted = setupCompleted;
      });
    } catch (_) {
      // The welcome screen keeps English fallbacks if localization setup fails.
    }
  }

  Future<void> _loadUiPreferences() async {
    try {
      final preferences = await _userData.readUiPreferences();
      if (!mounted) return;
      final darkMode = preferences['darkMode'];
      final animations = preferences['animationsEnabled'];
      final welcomeSeen = preferences['welcomeSeen'];
      setState(() {
        if (darkMode is bool) _darkMode = darkMode;
        if (animations is bool) _animationsEnabled = animations;
        if (welcomeSeen is bool) {
          _welcomeSeen = welcomeSeen;
          _showWelcome = !welcomeSeen;
        }
      });
    } catch (_) {
      // UI preference corruption must never prevent the dashboard from starting.
    }
  }

  void _saveUiPreferences() {
    unawaited(_userData.writeUiPreferences(<String, dynamic>{
      'darkMode': _darkMode,
      'animationsEnabled': _animationsEnabled,
      'welcomeSeen': _welcomeSeen,
    }));
  }

  void _completeWelcome(bool dontShowAgain) {
    setState(() {
      _welcomeSeen = dontShowAgain;
      _showWelcome = false;
      _showSetupWizard = !_setupWizardCompleted;
    });
    _saveUiPreferences();
  }

  void _completeSetupWizard(Map<String, dynamic> choices) {
    setState(() {
      _setupWizardCompleted = true;
      _showSetupWizard = false;
    });
    unawaited(() async {
      try {
        final settings = await _userData.readSettings();
        await _userData.writeSettings(<String, dynamic>{
          ...settings,
          ...choices,
        });
      } catch (_) {
        // A settings write failure must not block the dashboard.
      }
    }());
  }

  void _cancelSetupWizard() {
    setState(() => _showSetupWizard = false);
  }

  void _openDashboardFromWelcome() {
    setState(() => _showWelcome = false);
  }

  void _setDarkMode(bool value) {
    setState(() => _darkMode = value);
    _saveUiPreferences();
  }

  void _setAnimationsEnabled(bool value) {
    setState(() => _animationsEnabled = value);
    _saveUiPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final blockedRelease = HWControlAuthenticityGuard.requiresBlock;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale.fromSubtags(
        languageCode: _welcomeLocale.split('-').first,
        countryCode: _welcomeLocale.contains('-') ? _welcomeLocale.split('-').last : null,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _buildTheme(_darkMode),
      home: blockedRelease
          ? const UnofficialBuildScreen()
          : _showWelcome
              ? Directionality(
                  textDirection: HWControlLanguageService.isRightToLeft(_welcomeLocale)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: HWControlWelcomeScreen(
                    onContinue: _completeWelcome,
                    onSettings: _openDashboardFromWelcome,
                    translations: _welcomeTranslations,
                  ),
                )
              : _showSetupWizard
                  ? Directionality(
                      textDirection: HWControlLanguageService.isRightToLeft(_welcomeLocale)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: HWControlSetupWizard(
                        onComplete: _completeSetupWizard,
                        onCancel: _cancelSetupWizard,
                        translations: _welcomeTranslations,
                      ),
                    )
                  : DashboardScreen(
                  darkMode: _darkMode,
                  animationsEnabled: _animationsEnabled,
                  onThemeChanged: _setDarkMode,
                  onAnimationsChanged: _setAnimationsEnabled,
                  onLocaleChanged: (locale) => setState(() => _welcomeLocale = locale),
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
  const DashboardScreen({super.key, required this.darkMode, required this.animationsEnabled, required this.onThemeChanged, required this.onAnimationsChanged, required this.onLocaleChanged});

  final bool darkMode;
  final bool animationsEnabled;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<bool> onAnimationsChanged;
  final ValueChanged<String> onLocaleChanged;

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
  String _locale = 'en-US';
  String _languagePreference = HWControlLanguageService.systemDefault;
  String _languageStyle = HWControlLocalizationStyleService.standard;
  Map<String, String> _translations = <String, String>{};
  List<Map<String, String>> _supportedLocales = <Map<String, String>>[];
  bool _aiSending = false;
  DateTime? _lastAiAnalysisAt;
  String _aiStatus = 'Yerel AI başlatılmadı';
  bool _aiModelDownloading = false;
  double _aiModelProgress = 0;
  String? _aiModelError;
  String _aiAnalysis = 'Gemma 3 1B telemetry analizi bekleniyor';
  DateTime? _aiAnalysisTime;
  String _status = 'Bridge bekleniyor';
  String _lastAction = 'Henüz komut gönderilmedi';
  bool _isConnected = false;
  bool _isSending = false;
  bool _connecting = false;
  int _connectionGeneration = 0;
  bool _isCheckingUpdate = false;
  UpdateInfo? _updateInfo;
  String _updateStatus = '';
  double _fanValue = 50;
  double _aiValue = 80;
  double _temperatureLimit = 85;
  bool _notificationsEnabled = true;
  bool _piperTtsEnabled = false;
  String _piperExecutablePath = '';
  String _piperModelPath = '';
  final PiperTtsService _piperTts = PiperTtsService();
  bool _polling = false;
  double _cpuUsage = 0;
  int _cpuCoreCount = 0;
  double _cpuFrequencyMHz = 0;
  double _cpuTemperature = 0;
  double _memoryUsage = 0;
  double _diskUsage = 0;
  List<Map<String, dynamic>> _storageVolumes = <Map<String, dynamic>>[];
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
  bool _batteryPresent = false;
  bool _batteryDataAvailable = false;
  String _batteryStatus = 'unknown';
  double _batteryDesignCapacity = 0;
  double _batteryFullChargeCapacity = 0;
  String _batteryCapacityUnit = '';
  double _batteryHealthPercent = 0;
  int? _batteryCycleCount;
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
  bool _performanceModeEnabled = false;
  bool _performanceLabOpen = false;
  String _osPowerModeStatus = 'Not checked';
  double _prePerformanceFanValue = 50;
  double _prePerformanceAiValue = 80;
  bool _gameDetected = false;
  String _gameProcessName = '';
  final List<_MetricSample> _history = <_MetricSample>[];
  final List<String> _events = <String>[];
  final HWControlUserDataStore _userData = HWControlUserDataStore();
  String _thermalStatus = 'Veri bekleniyor';
  bool _thermalAlertActive = false;
  Map<String, Map<String, double>> _profiles = {};
  FanCurve _fanCurve = FanCurve.balanced;
  List<FanChannelTelemetry> _fanChannels = <FanChannelTelemetry>[];
  Map<String, FanChannelProfile> _fanChannelProfiles = <String, FanChannelProfile>{};
  final Map<String, FanCurveController> _fanChannelControllers = <String, FanCurveController>{};
  bool _smartFanEnabled = false;
  List<HardwareAutomationRule> _automationRules = <HardwareAutomationRule>[];
  final FanCurveController _fanCurveController = FanCurveController();
  bool _emergencyCoolingActive = false;
  bool _gameProfileApplied = false;
  double _preGameFanValue = 50;
  double _activeGameFanTarget = 50;
  final Map<String, double> _preGameFanChannelValues = <String, double>{};
  String _activeGameProfileProcess = '';
  Map<String, String> _gameProfiles = <String, String>{};
  bool _historyDirty = false;
  int _samplesSinceHistoryPersist = 0;
  static const _historySchema = 1;

  Future<File> get _telemetryHistoryFile async {
    return _userData.dataFile('telemetry-history.json.gz');
  }

  Future<File> get _legacyTelemetryHistoryFile async {
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

  Future<String> _defaultModelPath() async {
    return (await HWControlModelManager.modelFile()).path;
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
      if (executablePath == null) {
        if (mounted) setState(() => _aiStatus = 'ai_engine bulunamadı');
        return;
      }
      final modelReady = await HWControlModelManager.isReady();
      if (!modelReady) {
        if (mounted) {
          setState(() {
            _aiModelDownloading = true;
            _aiModelProgress = 0;
            _aiModelError = null;
            _aiStatus = 'Gemma 3 1B modeli indiriliyor...';
          });
        }
        try {
          await HWControlModelManager.ensureReady(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _aiModelProgress = progress.clamp(0.0, 1.0);
                _aiStatus = 'Gemma 3 1B modeli indiriliyor %${(_aiModelProgress * 100).round()}';
              });
            },
          );
        } catch (error) {
          if (mounted) {
            setState(() {
              _aiModelError = 'Model indirilemedi: $error';
              _aiStatus = 'Gemma 3 1B indirilemedi';
            });
          }
          return;
        } finally {
          if (mounted) setState(() => _aiModelDownloading = false);
        }
      }
      final modelPath = await _defaultModelPath();
      final environment = Map<String, String>.from(Platform.environment);
      // The AI engine is an unprivileged optional process. Never pass the
      // bridge authentication secret or IPC configuration into its environment.
      for (final key in const <String>[
        'HWCONTROL_KEY',
        'HWCONTROL_KEY_FILE',
        'HWCONTROL_SOCKET',
        'HWCONTROL_PORT',
      ]) {
        environment.remove(key);
      }
      environment['HWCONTROL_MODEL'] = modelPath;
      final process = await Process.start(
        executablePath,
        const ['--stdio'],
        environment: environment,
        runInShell: false,
      );
      _aiProcess = process;
      _aiResponses = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((_) {});
      process.exitCode.then((code) {
        if (_aiProcess == process) {
          _aiProcess = null;
          _aiResponses = null;
          if (mounted) setState(() => _aiStatus = code == 0 ? 'Yerel AI kapandı' : 'Yerel AI işlemi sonlandı');
        }
      });
      if (mounted) setState(() => _aiStatus = 'Gemma 3 1B yerel inference hazır');
    } catch (error) {
      _aiProcess = null;
      _aiResponses = null;
      if (mounted) setState(() => _aiStatus = 'Yerel AI başlatılamadı: $error');
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
      await _loadLanguage();
      await _loadProfiles();
      await _loadSettings();
      await _loadFanCurve();
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

  Future<void> _loadProfiles() async {
    try {
      final decoded = await _userData.readProfiles();
      if (!mounted) return;
      final profiles = <String, Map<String, double>>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final values = Map<String, dynamic>.from(entry.value as Map);
        final fan = (values['fan'] as num?)?.toDouble();
        final ai = (values['ai'] as num?)?.toDouble();
        if (fan == null || ai == null) continue;
        profiles[entry.key] = {
          'fan': fan.clamp(0, 100),
          'ai': ai.clamp(0, 100),
        };
      }
      setState(() => _profiles = profiles);
    } catch (_) {
      _addEvent('Profil dosyası okunamadı');
    }
  }

  String _tr(String key) => _translations[key] ?? key;

  Future<void> _loadLanguage() async {
    try {
      final locales = AppLocalizations.supportedLocales;
      _supportedLocales = <Map<String, String>>[
        for (final locale in locales.where((locale) => locale.countryCode != null))
          <String, String>{
            'code': localeTag(locale),
            'name': lookupAppLocalizations(locale).localeDisplayName,
          },
      ];
      final settings = await _userData.readSettings();
      final savedLocale = settings['language'] as String?;
      _languagePreference = savedLocale ?? HWControlLanguageService.systemDefault;
      _languageStyle = settings['languageStyle'] == HWControlLocalizationStyleService.literary
          ? HWControlLocalizationStyleService.literary
          : HWControlLocalizationStyleService.standard;
      _locale = HWControlLanguageService.resolveLocale(
        savedLocale: savedLocale,
        supportedCodes: locales.map(localeTag),
      );
      final baseTranslations =
          lookupAppLocalizations(localeFromTag(_locale)).toStringMap();
      _translations = await HWControlLocalizationStyleService.applyStyle(
        localeCode: _locale,
        style: _languageStyle,
        translations: baseTranslations,
      );
    } catch (_) {
      _locale = 'en-US';
      _languageStyle = HWControlLocalizationStyleService.standard;
      _translations = lookupAppLocalizations(const Locale('en', 'US')).toStringMap();
      _supportedLocales = <Map<String, String>>[
        <String, String>{'code': 'en-US', 'name': 'English (US)'},
      ];
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _userData.readSettings();
      if (!mounted) return;
      final notifications = settings['notificationsEnabled'];
      final limit = settings['temperatureLimit'];
      final smartFan = settings['smartFanEnabled'];
      final piperEnabled = settings['piperTtsEnabled'];
      final piperExecutable = settings['piperExecutablePath'];
      final piperModel = settings['piperModelPath'];
      final rawRules = settings['automationRules'];
      final rawGameProfiles = settings['gameProfiles'];
      final gameProfiles = <String, String>{};
      if (rawGameProfiles is Map) {
        for (final entry in rawGameProfiles.entries) {
          final process = _normalizeGameProcessName(entry.key.toString());
          final profile = entry.value;
          if (process.isNotEmpty && profile is String && profile.trim().isNotEmpty) {
            gameProfiles[process] = profile.trim();
          }
        }
      }
      final rules = rawRules is List ? rawRules.map(HardwareAutomationRule.fromJson).whereType<HardwareAutomationRule>().toList(growable: false) : const <HardwareAutomationRule>[];
      setState(() {
        if (notifications is bool) _notificationsEnabled = notifications;
        if (limit is num) {
          _temperatureLimit = limit.toDouble().clamp(60, 100);
        }
        if (smartFan is bool) _smartFanEnabled = smartFan;
        if (piperEnabled is bool) _piperTtsEnabled = piperEnabled;
        if (piperExecutable is String) _piperExecutablePath = piperExecutable;
        if (piperModel is String) _piperModelPath = piperModel;
        _gameProfiles = gameProfiles;
        _automationRules = rules.isEmpty
            ? const <HardwareAutomationRule>[
                HardwareAutomationRule(name: 'CPU thermal guard', sensor: 'cpuTemperature', threshold: 85, fanPercent: 80),
                HardwareAutomationRule(name: 'GPU thermal guard', sensor: 'gpuTemperature', threshold: 82, fanPercent: 80),
              ]
            : rules;
      });
    } catch (_) {
      _addEvent('Ayar dosyası okunamadı');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _userData.writeSettings(<String, dynamic>{
        'notificationsEnabled': _notificationsEnabled,
        'temperatureLimit': _temperatureLimit,
        'language': _languagePreference,
        'languageStyle': _languageStyle,
        'smartFanEnabled': _smartFanEnabled,
        'piperTtsEnabled': _piperTtsEnabled,
        'piperExecutablePath': _piperExecutablePath,
        'piperModelPath': _piperModelPath,
        'gameProfiles': _gameProfiles,
        'automationRules': _automationRules.map((rule) => rule.toJson()).toList(growable: false),
      });
    } catch (_) {
      _addEvent('Ayarlar kaydedilemedi');
    }
  }

  Future<void> _loadFanCurve() async {
    try {
      final curves = await _userData.readFanCurves();
      final defaultCurve = FanCurve.fromJson(curves['default']);
      final rawProfiles = curves['channelProfiles'];
      final profiles = <String, FanChannelProfile>{};
      if (rawProfiles is Map) {
        for (final entry in rawProfiles.entries) {
          final id = entry.key.toString();
          if (id.isEmpty) continue;
          profiles[id] = FanChannelProfile.fromJson(
            entry.value,
            fallbackCurve: defaultCurve,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _fanCurve = defaultCurve;
        _fanChannelProfiles = profiles;
      });
    } catch (_) {
      _addEvent('Fan eğrisi okunamadı; güvenli varsayılan kullanılıyor');
    }
  }

  Future<void> _persistFanCurves() async {
    try {
      final curves = await _userData.readFanCurves();
      curves['default'] = _fanCurve.toJson();
      curves['channelProfiles'] = _fanChannelProfiles.map(
        (id, profile) => MapEntry(id, profile.toJson()),
      );
      await _userData.writeFanCurves(curves);
    } catch (_) {
      _addEvent('Fan profilleri kaydedilemedi');
    }
  }

  FanChannelProfile _profileForFanChannel(FanChannelTelemetry channel) =>
      _fanChannelProfiles[channel.id] ??
      FanChannelProfile(curve: _fanCurve);

  void _updateFanChannelProfile(
    String channelId,
    FanChannelProfile profile, {
    bool resetController = true,
  }) {
    setState(() => _fanChannelProfiles[channelId] = profile);
    if (resetController) _fanChannelControllers.remove(channelId)?.reset();
    unawaited(_persistFanCurves());
  }

  Future<void> _openFanCurveEditor() async {
    await showDialog<void>(
      context: context,
      builder: (context) => FanCurveEditor(
        translations: _translations,
        initialCurve: _fanCurve,
        onSave: (curve) {
          _fanCurve = curve;
          unawaited(_persistFanCurves());
          if (mounted) {
            setState(() {});
            _addEvent('Smart Fan eğrisi kaydedildi');
          }
        },
      ),
    );
  }

  Future<void> _openBenchmark() async {
    await showDialog<void>(
      context: context,
      builder: (context) => HardwareBenchmarkDialog(
        translations: _translations,
      ),
    );
  }

  Future<HardwareAutomationRule?> _editAutomationRuleDialog({HardwareAutomationRule? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final threshold = TextEditingController(text: (initial?.threshold ?? 80).toString());
    final fan = TextEditingController(text: (initial?.fanPercent ?? 70).round().toString());
    var sensor = initial?.sensor ?? 'cpuTemperature';
    final result = await showDialog<HardwareAutomationRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(initial == null ? _tr('newAutomationRule') : _tr('editAutomationRule')),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: _tr('ruleName'))),
                DropdownButtonFormField<String>(
                  initialValue: sensor,
                  decoration: InputDecoration(labelText: _tr('sensor')),
                  items: [
                    DropdownMenuItem(value: 'cpuTemperature', child: Text(_tr('cpuTemperatureLabel'))),
                    DropdownMenuItem(value: 'gpuTemperature', child: Text(_tr('gpuTemperatureLabel'))),
                  ],
                  onChanged: (value) => setDialogState(() => sensor = value ?? sensor),
                ),
                TextField(controller: threshold, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: _tr('threshold'))),
                TextField(controller: fan, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: _tr('fanTarget'))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_tr('cancel'))),
            FilledButton(
              onPressed: () {
                final cleanName = name.text.trim();
                final t = double.tryParse(threshold.text);
                final f = double.tryParse(fan.text);
                if (cleanName.isEmpty || t == null || f == null || !t.isFinite || !f.isFinite || f < 0 || f > 100) return;
                Navigator.pop(context, HardwareAutomationRule(
                  name: cleanName,
                  sensor: sensor,
                  threshold: t.clamp(20, 110).toDouble(),
                  fanPercent: f.clamp(0, 100).toDouble(),
                  enabled: initial?.enabled ?? true,
                ));
              },
              child: Text(_tr('save')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    threshold.dispose();
    fan.dispose();
    return result;
  }

  Future<void> _openAutomationRules() async {
    var rules = [..._automationRules];
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tr('hardwareAutomation')),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_tr('automationSafetyNote')),
                  const SizedBox(height: 12),
                  for (var i = 0; i < rules.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(rules[i].name),
                      subtitle: Text(
                        AppLocalizations.of(context).automationRuleSummary(
                          _tr(rules[i].sensor == 'cpuTemperature'
                              ? 'cpuTemperatureLabel'
                              : 'gpuTemperatureLabel'),
                          rules[i].threshold.round(),
                          rules[i].fanPercent.round(),
                        ),
                      ),
                      leading: Switch(
                        value: rules[i].enabled,
                        onChanged: (value) => setDialogState(() {
                          rules[i] = HardwareAutomationRule(
                            name: rules[i].name,
                            sensor: rules[i].sensor,
                            threshold: rules[i].threshold,
                            fanPercent: rules[i].fanPercent,
                            enabled: value,
                          );
                        }),
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: _tr('edit'),
                            onPressed: () async {
                              final edited = await _editAutomationRuleDialog(initial: rules[i]);
                              if (edited != null) setDialogState(() => rules[i] = edited);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: _tr('delete'),
                            onPressed: () => setDialogState(() => rules.removeAt(i)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  if (rules.isEmpty) Text(_tr('noAutomationRules')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await _editAutomationRuleDialog();
                        if (created != null) setDialogState(() => rules.add(created));
                      },
                      icon: const Icon(Icons.add),
                      label: Text(_tr('addRule')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_tr('cancel'))),
            FilledButton(
              onPressed: () {
                _automationRules = List<HardwareAutomationRule>.unmodifiable(rules);
                _fanCurveController.reset();
                unawaited(_saveSettings());
                if (mounted) setState(() {});
                Navigator.pop(context);
              },
              child: Text(_tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeGameProcessName(String name) =>
      normalizeGameProcessName(name);

  Future<void> _openGameProfileManager() async {
    final process = _normalizeGameProcessName(_gameProcessName);
    if (!_gameDetected || process.isEmpty) {
      _addEvent('Önce desteklenen bir oyun algılanmalı');
      return;
    }
    final names = _profiles.keys.toList()..sort();
    if (names.isEmpty) {
      _addEvent('Önce Kontroller bölümünden en az bir profil kaydedin');
      return;
    }
    var selected = _gameProfiles[process];
    if (selected != null && !names.contains(selected)) selected = null;
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tr('gameMode')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(process),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: InputDecoration(labelText: _tr('saveProfile')),
                  items: [
                    for (final name in names)
                      DropdownMenuItem<String>(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setDialogState(() => selected = value),
                ),
                const SizedBox(height: 8),
                Text(_tr('gameModeDescription')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(_tr('reset')),
            ),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(context, selected),
              child: Text(_tr('save')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.isEmpty) {
        _gameProfiles.remove(process);
      } else {
        _gameProfiles[process] = result;
      }
    });
    await _saveSettings();
    _addEvent(result.isEmpty ? '$process oyun profili ataması kaldırıldı' : '$process için $result profili atandı');
  }

  Future<void> _applyGameModeProfile(Map<String, dynamic> telemetry) async {
    if (!_isConnected || _isSending) return;
    final supportedChannels = _fanChannels
        .where((channel) => channel.supported && channel.id.isNotEmpty)
        .toList(growable: false);
    final detected = _gameModeEnabled && telemetry['gameDetected'] == true;
    final process = _normalizeGameProcessName(
      telemetry['gameProcessName'] as String? ?? _gameProcessName,
    );
    final sameGame = detected &&
        _gameProfileApplied &&
        process == _activeGameProfileProcess;
    final hadActiveSession = _gameProfileApplied;

    // Restore the pre-game targets on disable, exit, or game switch. Channel
    // profiles use an independent baseline for each currently detected fan.
    if (_gameProfileApplied && !sameGame) {
      var restored = true;
      if (supportedChannels.isNotEmpty) {
        for (final channel in supportedChannels) {
          final baseline = (_preGameFanChannelValues[channel.id] ??
                  _profileForFanChannel(channel).manualPercent)
              .clamp(20, 100)
              .toDouble();
          final success = await _sendCommand(
            'Set Fan Channel',
            baseline,
            target: channel.id,
          );
          if (!success) restored = false;
        }
      } else if (_fanControlSupported) {
        restored = await _sendCommand(
          'Fan Hızı',
          _preGameFanValue.clamp(1, 100).toDouble(),
        );
      }

      if (!restored) {
        _addEvent('Game Mode önceki fan hedeflerini geri yükleyemedi');
        return;
      }
      _gameProfileApplied = false;
      _activeGameProfileProcess = '';
      _activeGameFanTarget = 50;
      if (!detected) _preGameFanChannelValues.clear();
      if (mounted) {
        setState(() {
          _fanValue = _preGameFanValue.clamp(1, 100).toDouble();
        });
      }
      _addEvent('Game Mode önceki fan hedeflerini geri yükledi');
    }

    if (!detected ||
        (!_fanControlSupported && supportedChannels.isEmpty) ||
        _gameProfileApplied) {
      return;
    }

    // Keep the original baseline when switching directly between games.
    if (!hadActiveSession) {
      _preGameFanValue = _fanValue.clamp(1, 100).toDouble();
      _preGameFanChannelValues
        ..clear()
        ..addEntries(supportedChannels.map((channel) {
          final baseline = channel.percentAvailable
              ? channel.fanPercent
              : _profileForFanChannel(channel).manualPercent;
          return MapEntry(
            channel.id,
            baseline.clamp(20, 100).toDouble(),
          );
        }));
    }

    final assignedName = assignedGameProfileName(
      processName: process,
      assignments: _gameProfiles,
    );
    final target = resolveGameProfileFanTarget(
      processName: process,
      assignments: _gameProfiles,
      profiles: _profiles,
    );
    final selectedTarget = supportedChannels.isEmpty
        ? target.clamp(1, 100).toDouble()
        : target.clamp(20, 100).toDouble();

    var success = true;
    if (supportedChannels.isNotEmpty) {
      for (final channel in supportedChannels) {
        final applied = await _sendCommand(
          'Set Fan Channel',
          selectedTarget,
          target: channel.id,
        );
        if (!applied) {
          success = false;
          break;
        }
      }
      if (!success) {
        // Best-effort rollback if a multi-channel preset only partially
        // applied. Do not report Game Mode as active after a partial write.
        for (final channel in supportedChannels) {
          final baseline = _preGameFanChannelValues[channel.id];
          if (baseline == null) continue;
          await _sendCommand(
            'Set Fan Channel',
            baseline.clamp(20, 100).toDouble(),
            target: channel.id,
          );
        }
      }
    } else {
      success = await _sendCommand('Fan Hızı', selectedTarget);
    }

    if (success) {
      _gameProfileApplied = true;
      _activeGameProfileProcess = process;
      _activeGameFanTarget = selectedTarget;
      if (mounted) setState(() => _fanValue = selectedTarget);
      _addEvent(
        assignedName == null
            ? 'Game Mode oyun fan hedefini kanallara uyguladı'
            : '$process için $assignedName fan hedefi uygulandı',
      );
    } else {
      _addEvent('Game Mode fan hedefi tüm kanallara uygulanamadı');
    }
  }

  Future<bool> _sendEmergencyCoolingTarget(
    List<FanChannelTelemetry> supportedChannels,
  ) async {
    if (supportedChannels.isEmpty) {
      if (!_fanControlSupported) return false;
      if (_fanValue >= 100) return true;
      final success = await _sendCommand('Fan Hızı', 100);
      if (success && mounted) setState(() => _fanValue = 100);
      return success;
    }

    var allSuccessful = true;
    for (final channel in supportedChannels) {
      if (channel.percentAvailable && channel.fanPercent >= 99.5) continue;
      final success = await _sendCommand(
        'Set Fan Channel',
        100,
        target: channel.id,
      );
      if (!success) allSuccessful = false;
    }
    return allSuccessful;
  }

  Future<void> _applyAutomaticFanControl(Map<String, dynamic> telemetry) async {
    final supportedChannels = _fanChannels
        .where((channel) => channel.supported && channel.id.isNotEmpty)
        .toList(growable: false);
    if (!_isConnected ||
        _isSending ||
        (!_fanControlSupported && supportedChannels.isEmpty)) {
      return;
    }

    final cpu = (telemetry['cpuTemperature'] as num?)?.toDouble() ?? double.nan;
    final gpu = (telemetry['gpuTemperature'] as num?)?.toDouble() ?? double.nan;
    final cpuValid = isUsableFanTemperature(cpu);
    final gpuValid = isUsableFanTemperature(gpu);

    // Emergency cooling is independent of normal per-channel automation.
    // The bridge independently enforces the same critical-temperature rule.
    final criticalThermal = (cpuValid && cpu >= 95) || (gpuValid && gpu >= 95);
    final anyValidThermal = cpuValid || gpuValid;
    final emergencyReleaseReached = anyValidThermal &&
        (!cpuValid || cpu < 92) &&
        (!gpuValid || gpu < 92);

    if (_emergencyCoolingActive && !emergencyReleaseReached) {
      _fanCurveController.reset();
      for (final controller in _fanChannelControllers.values) {
        controller.reset();
      }
      final success = await _sendEmergencyCoolingTarget(supportedChannels);
      if (success) _addEvent('Acil soğutma hedefi %100 olarak korundu');
      return;
    }
    if (_emergencyCoolingActive && emergencyReleaseReached) {
      _emergencyCoolingActive = false;
      _fanCurveController.reset();
      for (final controller in _fanChannelControllers.values) {
        controller.reset();
      }
      _addEvent('Sıcaklıklar güvenli bırakma eşiğinin altına indi; acil soğutma kilidi kaldırıldı');
    }
    if (criticalThermal) {
      _fanCurveController.reset();
      for (final controller in _fanChannelControllers.values) {
        controller.reset();
      }
      final success = await _sendEmergencyCoolingTarget(supportedChannels);
      if (success) {
        _emergencyCoolingActive = true;
        _addEvent('Kritik sıcaklık algılandı; desteklenen fan kanallarında acil soğutma uygulandı');
      } else {
        _addEvent('Kritik sıcaklık algılandı fakat acil fan komutu doğrulanamadı');
      }
      return;
    }

    // The master switch and each channel's own automatic-enable setting must
    // both be active before normal curve control can run.
    if (!_smartFanEnabled) return;

    final ruleTarget = HardwareAutomationEngine(_automationRules).evaluate(<String, dynamic>{
      'cpuTemperature': cpu,
      'gpuTemperature': gpu,
    });

    if (supportedChannels.isNotEmpty) {
      for (final channel in supportedChannels) {
        final profile = _profileForFanChannel(channel);
        if (!profile.automaticEnabled) continue;

        final controlTemperature = selectFanControlTemperature(
          sensorSource: profile.sensorSource,
          cpuTemperature: cpu,
          gpuTemperature: gpu,
        );
        final controller = _fanChannelControllers.putIfAbsent(
          channel.id,
          () => FanCurveController(),
        );
        final curveTarget = controller.nextTarget(
          curve: profile.curve,
          temperature: controlTemperature ?? double.nan,
          now: DateTime.now(),
          sensorValid: isUsableFanTemperature(controlTemperature),
          hardwareControlSupported: channel.supported,
        );
        final currentFanPercent = channel.percentAvailable
            ? channel.fanPercent
            : profile.manualPercent;
        final automaticTarget = resolveAutomaticFanTarget(
          curveTarget: curveTarget,
          ruleTarget: ruleTarget,
          currentFanPercent: currentFanPercent,
        );
        if (automaticTarget == null || !automaticTarget.isFinite) continue;

        var target = automaticTarget.clamp(20, 100).toDouble();
        // A game-specific fan request is a floor, not permission to defeat a
        // stronger per-channel thermal curve.
        if (_gameProfileApplied) {
          target = math.max(
            math.max(target, currentFanPercent),
            _activeGameFanTarget,
          ).clamp(20, 100).toDouble();
        }
        final success = await _sendCommand(
          'Set Fan Channel',
          target,
          target: channel.id,
        );
        if (success) {
          _addEvent('${channel.name}: otomatik fan hedefi ${target.round()}%');
        }
      }
      return;
    }

    // Backwards-compatible path for a platform exposing only the legacy
    // single-fan adapter and no independently addressable channels.
    final controlTemperature = selectFanControlTemperature(
      sensorSource: 'hottest',
      cpuTemperature: cpu,
      gpuTemperature: gpu,
    );
    final curveTarget = _fanCurveController.nextTarget(
      curve: _fanCurve,
      temperature: controlTemperature ?? double.nan,
      now: DateTime.now(),
      sensorValid: isUsableFanTemperature(controlTemperature),
      hardwareControlSupported: _fanControlSupported,
    );
    final automaticTarget = resolveAutomaticFanTarget(
      curveTarget: curveTarget,
      ruleTarget: ruleTarget,
      currentFanPercent: _fanValue,
    );
    if (automaticTarget == null || !automaticTarget.isFinite) return;
    final target = (_gameProfileApplied
            ? math.max(
                math.max(_fanValue, automaticTarget),
                _activeGameFanTarget,
              )
            : automaticTarget)
        .clamp(20, 100)
        .toDouble();
    final success = await _sendCommand('Fan Hızı', target);
    if (success) {
      if (mounted) setState(() => _fanValue = target);
      _addEvent('Smart Fan otomatik hedef: ${target.round()}%');
    }
  }

  Future<void> _loadTelemetryHistory() async {
    try {
      var file = await _telemetryHistoryFile;
      var migratedFromLegacy = false;
      if (!await file.exists()) {
        final legacy = await _legacyTelemetryHistoryFile;
        if (await legacy.exists()) {
          file = legacy;
          migratedFromLegacy = true;
        }
      }
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
      if (migratedFromLegacy) {
        try {
          final target = await _telemetryHistoryFile;
          await file.copy(target.path);
          await file.delete();
          _addEvent('Telemetry geçmişi yeni data dizinine taşındı');
        } catch (_) {
          _addEvent('Telemetry geçmişi yüklendi; eski konumdan taşınamadı');
        }
      } else {
        _addEvent('Sıkıştırılmış telemetry geçmişi yüklendi');
      }
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
      final temporary = File('${file.path}.tmp');
      final backup = File('${file.path}.old');
      await temporary.writeAsBytes(compressed, flush: true);
      if (await backup.exists()) {
        await backup.delete();
      }
      if (await file.exists()) {
        await file.rename(backup.path);
      }
      try {
        await temporary.rename(file.path);
      } catch (_) {
        if (await backup.exists() && !await file.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }
      if (await backup.exists()) {
        await backup.delete();
      }
      _historyDirty = false;
      _samplesSinceHistoryPersist = 0;
    } catch (_) {
      // Persistence is best-effort; telemetry collection must continue.
    }
  }

  Future<void> _saveProfile(String name) async {
    _profiles[name] = {'fan': _fanValue, 'ai': _aiValue};
    try {
      await _userData.writeProfiles(
        _profiles.map((key, value) => MapEntry(key, value)),
      );
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

  Future<void> _openHealthCenter() async {
    final health = await _requestBridgeData('Get Health');
    final status = await _requestBridgeData('Get Status');
    final sensorHistory = await _requestBridgeData('Get Sensor History');
    if (!mounted) return;
    if (health == null) {
      setState(() => _status = 'Health Center için bridge bağlantısı gerekli');
      return;
    }
    final metrics = status ?? const <String, dynamic>{};
    final anomalies = (health['anomalies'] as List?)?.whereType<Map>().toList(growable: false) ?? const <Map>[];
    final warnings = (health['warnings'] as List?)?.map((value) => value.toString()).toList(growable: false) ?? const <String>[];
    final sensorSamples = (sensorHistory?['samples'] as List?)?.whereType<Map>().toList(growable: false) ?? const <Map>[];
    final recentSensorSamples = sensorSamples.length > 10 ? sensorSamples.sublist(sensorSamples.length - 10) : sensorSamples;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('hardwareHealthCenter')),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_tr('status')}: ${health['status'] ?? _tr('unknown')}'),
                Text('${_tr('safety')}: ${health['safetyState'] ?? _tr('unknown')}'),
                Text('${_tr('recovery')}: ${health['recoveryAction'] ?? _tr('none')}'),
                const Divider(),
                Text('${_tr('cpuTemperatureLabel')}: ${_formatHealthMetric(metrics['cpuTemperature'], '°C')} • ${_tr('usage')}: ${_formatHealthMetric(metrics['cpuUsage'], '%')}'),
                Text('${_tr('gpuTemperatureLabel')}: ${_formatHealthMetric(metrics['gpuTemperature'], '°C')} • ${_formatHealthMetric(metrics['gpuUsage'], '%')}'),
                Text('${_tr('fanSpeed')}: ${_formatHealthMetric(metrics['fanRpm'], 'RPM')} • ${_formatHealthMetric(metrics['fanPercent'], '%')}'),
                Text('${_tr('power')}: ${_formatHealthMetric(metrics['powerWatts'], 'W')} • ${_tr('voltage')}: ${_formatHealthMetric(metrics['voltage'], 'V')}'),
                Text('${_feedbackText('CPU sensör kaynağı', 'CPU sensor source')}: ${health['cpuTemperatureSource'] ?? metrics['cpuTemperatureSource'] ?? 'N/A'}'),
                Text('${_feedbackText('GPU sensör kaynağı', 'GPU sensor source')}: ${health['gpuTemperatureSource'] ?? metrics['gpuTemperatureSource'] ?? 'N/A'}'),
                Text('${_feedbackText('Son örnek zamanı', 'Latest sample time')}: ${health['metricsCollectedAt'] ?? metrics['metricsCollectedAt'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('${_feedbackText('Yerel sensör geçmişi', 'Local sensor history')} (${sensorHistory?['sampleCount'] ?? 0})', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (recentSensorSamples.isEmpty)
                  Text(_feedbackText('Henüz sensör geçmişi örneği yok.', 'No sensor history samples yet.')),
                for (final sample in recentSensorSamples.reversed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${sample['timestamp'] ?? 'N/A'} • CPU ${_formatHealthMetric(sample['cpuTemperature'], '°C')} • GPU ${_formatHealthMetric(sample['gpuTemperature'], '°C')} • Fan ${_formatHealthMetric(sample['fanRpm'], 'RPM')}',
                    ),
                  ),
                const SizedBox(height: 8),
                if (warnings.isNotEmpty) ...[
                  Text(_tr('warnings'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final warning in warnings) Text('• $warning'),
                  const SizedBox(height: 10),
                ],
                Text(AppLocalizations.of(context).anomalyCount(anomalies.length), style: const TextStyle(fontWeight: FontWeight.w700)),
                for (final anomaly in anomalies)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${anomaly['severity'] ?? _tr('unknown')} • ${anomaly['code'] ?? _tr('unknown')} • ${anomaly['message'] ?? ''}'),
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(_tr('close')))],
      ),
    );
  }

  String _formatHealthMetric(dynamic value, String unit) {
    final number = (value as num?)?.toDouble();
    if (number == null || !number.isFinite || number <= 0) return 'N/A';
    return '${number.toStringAsFixed(unit == '%' || unit == '°C' ? 1 : 0)} $unit';
  }

  String _feedbackText(String turkish, String english) =>
      Localizations.localeOf(context).languageCode == 'tr' ? turkish : english;

  Future<void> _openFeedbackDestination(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() => _status = _feedbackText(
          'Geri bildirim bağlantısı açılamadı',
          'Could not open the feedback link',
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = _feedbackText(
          'Geri bildirim bağlantısı açılamadı',
          'Could not open the feedback link',
        ));
      }
    }
  }

  Future<void> _showFeedbackOptions() async {
    const bugUrl =
        'https://github.com/lordkeremello45/HWcontrol2.0/issues/new?template=bug_report.yml';
    const featureUrl =
        'https://github.com/lordkeremello45/HWcontrol2.0/issues/new?template=feature_request.yml';
    const generalUrl =
        'https://github.com/lordkeremello45/HWcontrol2.0/issues/new/choose';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_feedbackText('HWcontrol2.0 geri bildirimi', 'HWcontrol2.0 feedback')),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_feedbackText(
                'Hangi konuda yardımcı olmak istiyorsun? Bağlantı GitHub üzerinde açılır; gönder tuşuna basmadan önce içeriği inceleyebilirsin.',
                'What would you like to share? This opens GitHub; review the content before submitting it.',
              )),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(_feedbackText('Hata bildir', 'Report a bug')),
                subtitle: Text(_feedbackText(
                  'Beklenen davranışı, gerçek sonucu ve tekrar adımlarını ekle.',
                  'Include expected behavior, actual behavior, and reproduction steps.',
                )),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openFeedbackDestination(bugUrl));
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(_feedbackText('Özellik veya deneyim öner', 'Suggest a feature or UX improvement')),
                subtitle: Text(_feedbackText(
                  'Önce çözmek istediğin kullanıcı sorununu anlat.',
                  'Start with the user problem you want to solve.',
                )),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openFeedbackDestination(featureUrl));
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(_feedbackText('Diğer geri bildirimler', 'Other feedback')),
                subtitle: Text(_feedbackText(
                  'Mevcut konuları kontrol et veya uygun şablonu seç.',
                  'Check existing reports or choose the appropriate template.',
                )),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openFeedbackDestination(generalUrl));
                },
              ),
              const SizedBox(height: 8),
              Text(
                _feedbackText(
                  'Gizlilik: Tanılama dosyaları otomatik gönderilmez. Ek dosya paylaşmadan önce sırları ve kişisel bilgileri kaldır.',
                  'Privacy: diagnostic files are never submitted automatically. Remove secrets and personal information before sharing attachments.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_tr('close')),
          ),
        ],
      ),
    );
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

  String _commandNonce() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  String _commandAuth({
    required String action,
    required double value,
    required int timestamp,
    required String nonce,
    String? target,
  }) {
    var payload = '$action\n${value.toStringAsFixed(6)}\n$timestamp\n$nonce';
    if (target != null && target.isNotEmpty) payload = '$payload\n$target';
    return Hmac(sha256, utf8.encode(_sharedKey)).convert(utf8.encode(payload)).toString();
  }


  Future<Map<String, dynamic>?> _requestLocalAudioProfile(Map<String, dynamic> profile) async {
    if (_aiSending) throw StateError('Gemma is currently processing another request.');
    _aiSending = true;
    try {
      await _ensureAiEngine();
      final process = _aiProcess;
      final responses = _aiResponses;
      if (process == null || responses == null) {
        throw StateError(_aiModelError ?? 'Local Gemma engine is not ready.');
      }
      final deviceType = profile['deviceType'];
      final usage = profile['usage'];
      final model = profile['model'];
      final manufacturer = profile['manufacturer'] is String ? profile['manufacturer'] as String : '';
      final sampleRate = profile['sampleRateHz'];
      final channels = profile['channels'];
      if (deviceType is! String || usage is! String || model is! String ||
          sampleRate is! int || channels is! int ||
          model.trim().isEmpty || utf8.encode(model).length > 120 || utf8.encode(manufacturer).length > 80 ||
          sampleRate < 8000 || sampleRate > 192000 || channels < 1 || channels > 8) {
        throw const FormatException('Audio profile input is outside supported bounds.');
      }
      const deviceTypes = {'microphone', 'speaker', 'headphones', 'headset'};
      const useCases = {'voice', 'gaming', 'music', 'movie', 'meeting', 'streaming', 'broadcast'};
      if (!deviceTypes.contains(deviceType) || !useCases.contains(usage)) {
        throw const FormatException('Unsupported device type or use case.');
      }
      final fields = <String>[
        'AUDIO',
        'type=$deviceType',
        'usage=$usage',
        'rate=$sampleRate',
        'channels=$channels',
        'model_hex=${_hexEncode(model)}',
        if (manufacturer.isNotEmpty) 'manufacturer_hex=${_hexEncode(manufacturer)}',
        'verified=${_aiBool(profile['specificationsVerified'])}',
      ];
      process.stdin.writeln(fields.join(' '));
      await process.stdin.flush();
      final hasResponse = await responses.moveNext().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          process.kill();
          _aiProcess = null;
          _aiResponses = null;
          unawaited(responses.cancel());
          throw TimeoutException('Local Gemma audio recommendation timed out.');
        },
      );
      if (!hasResponse) throw StateError('Local Gemma process closed without a response.');
      final response = responses.current;
      if (!response.startsWith('AUDIO_OK|')) {
        throw StateError(response.startsWith('AUDIO_ERROR|') ? response : 'Local Gemma returned an unexpected response.');
      }
      return <String, dynamic>{
        'recommendation': response.substring('AUDIO_OK|'.length).trim(),
        'localOnly': true,
        'requiresApproval': true,
      };
    } catch (error) {
      if (mounted) setState(() => _aiStatus = 'Audio advisor: $error');
      rethrow;
    } finally {
      _aiSending = false;
    }
  }

  Future<Map<String, dynamic>?> _requestAudioStudioControl(
    String action,
    Map<String, dynamic>? payload,
  ) async {
    final socket = _socket;
    if (!_isConnected || socket == null || _sharedKey.isEmpty) {
      throw StateError('Connect to the authenticated local bridge before controlling audio.');
    }
    if (action == 'Stop Audio Studio') {
      var attempts = 0;
      while (_isSending && attempts < 120) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        attempts++;
      }
    }
    if (_isSending) throw StateError('Another bridge request is in progress.');
    String? target;
    if (payload != null) {
      target = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    }
    _isSending = true;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _commandNonce();
      final auth = _commandAuth(
        action: action,
        value: 0.0,
        timestamp: timestamp,
        nonce: nonce,
        target: target,
      );
      final request = <String, dynamic>{
        'action': action,
        'value': 0.0,
        'timestamp': timestamp,
        'nonce': nonce,
        'auth': auth,
      };
      if (target != null) request['target'] = target;
      socket.write('${jsonEncode(request)}\n');
      final responses = _responses;
      if (responses == null || !await responses.moveNext().timeout(const Duration(seconds: 5))) {
        throw StateError('Audio bridge response timed out.');
      }
      final response = jsonDecode(responses.current) as Map<String, dynamic>;
      if (response['status'] != 'SUCCESS') {
        throw StateError(response['message'] is String ? response['message'] as String : 'Audio bridge command failed.');
      }
      final data = response['data'];
      return data is Map<String, dynamic> ? data : null;
    } finally {
      _isSending = false;
    }
  }

  Future<Map<String, dynamic>?> _requestBridgeData(String action) async {
    final socket = _socket;
    if (!_isConnected || socket == null || _sharedKey.isEmpty || _isSending) return null;
    _isSending = true;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _commandNonce();
      final auth = _commandAuth(action: action, value: 0.0, timestamp: timestamp, nonce: nonce);
      socket.write('${jsonEncode({
        'action': action,
        'value': 0.0,
        'timestamp': timestamp,
        'nonce': nonce,
        'auth': auth,
      })}\n');
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
    return '"${value.replaceAll('"', '""')}"';
  }

  Future<void> _exportTelemetryHistory() async {
    try {
      final directory = await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${directory.path}${Platform.pathSeparator}HWControl-Telemetry-$stamp.csv');
      final buffer = StringBuffer('timestamp,cpu_temperature,cpu_usage,cpu_frequency_mhz,gpu_temperature,gpu_usage,gpu_core_clock_mhz,gpu_power_watts,gpu_memory_usage,fan_percent,fan_rpm,memory_usage,disk_usage,thermal_status\\n');
      for (final sample in _history) {
        buffer.writeln([sample.time.toUtc().toIso8601String(), sample.cpuTemperature, sample.cpuUsage, sample.cpuFrequencyMHz, sample.gpuTemperature, sample.gpuUsage, sample.gpuCoreClockMHz, sample.gpuPowerWatts, sample.gpuMemoryUsage, sample.fanPercent, sample.fanRpm, sample.memoryUsage, sample.diskUsage, _csvEscape(_thermalStatus)].join(','));
      }
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      setState(() => _status = 'Telemetry CSV oluşturuldu: ${file.path}');
      _addEvent('Telemetry geçmişi dışa aktarıldı');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Telemetry dışa aktarılamadı');
      _addEvent('Telemetry export hatası: $error');
    }
  }
  Future<void> _refreshMetrics() async {
    if (!_isConnected || _isSending) return;
    final data = await _requestBridgeData('Get Status');
    if (!mounted || data == null) return;
    final temperature = (data['cpuTemperature'] as num?)?.toDouble() ?? 0;
    final thresholdExceeded = _notificationsEnabled && temperature >= _temperatureLimit;
    final rawBattery = data['battery'];
    final batteryData = rawBattery is Map
        ? Map<String, dynamic>.from(rawBattery)
        : const <String, dynamic>{};
    final rawFanChannels = (data['fanChannels'] as List?) ?? const <dynamic>[];
    final fanChannels = rawFanChannels
        .whereType<Map>()
        .map((entry) => FanChannelTelemetry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    setState(() {
      _cpuUsage = (data['cpuUsage'] as num?)?.toDouble() ?? 0;
      _cpuCoreCount = (data['cpuCoreCount'] as num?)?.toInt() ?? 0;
      _cpuFrequencyMHz = (data['cpuFrequencyMHz'] as num?)?.toDouble() ?? 0;
      _cpuTemperature = temperature;
      _memoryUsage = (data['memoryUsage'] as num?)?.toDouble() ?? 0;
      _diskUsage = (data['diskUsage'] as num?)?.toDouble() ?? 0;
      _storageVolumes = ((data['storageVolumes'] as List?) ?? const <dynamic>[]).whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList(growable: false);
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
      _fanChannels = fanChannels;
      _batteryPresent = batteryData['present'] as bool? ?? false;
      _batteryDataAvailable = batteryData['dataAvailable'] as bool? ?? false;
      _batteryStatus = batteryData['status'] as String? ?? 'unknown';
      _batteryDesignCapacity = (batteryData['designCapacity'] as num?)?.toDouble() ?? 0;
      _batteryFullChargeCapacity = (batteryData['fullChargeCapacity'] as num?)?.toDouble() ?? 0;
      _batteryCapacityUnit = batteryData['capacityUnit'] as String? ?? '';
      _batteryHealthPercent = (batteryData['healthPercent'] as num?)?.toDouble() ?? 0;
      _batteryCycleCount = (batteryData['cycleCount'] as num?)?.toInt();
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
        _events.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)}  $_thermalStatus');
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
    await _applyGameModeProfile(data);
    await _applyAutomaticFanControl(data);
    if (_samplesSinceHistoryPersist >= 12) unawaited(_persistTelemetryHistory());
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
        final assets = (release['assets'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();
        final candidates = Platform.isWindows
            ? <String>['Setup.exe', '.exe', '.msi', '.zip']
            : Platform.isMacOS
                ? <String>['.dmg', '.pkg']
                : <String>['.deb', '.tar.zst', '.tar.gz'];
        Map<String, dynamic>? selected;
        for (final suffixCandidate in candidates) {
          selected = assets.cast<Map<String, dynamic>?>().firstWhere(
            (asset) => (asset?['name'] as String? ?? '').toLowerCase().endsWith(suffixCandidate.toLowerCase()),
            orElse: () => null,
          );
          if (selected != null) break;
        }
        if (selected == null) continue;
        final assetUrl = selected['browser_download_url'] as String? ?? '';
        if (!assetUrl.startsWith('https://github.com/lordkeremello45/HWcontrol2.0/releases/download/')) continue;
        final rawDigest = selected['digest'] as String?;
        if (rawDigest == null || !rawDigest.startsWith('sha256:')) continue;
        final digest = rawDigest.substring(7).trim();
        if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) continue;
        final assetName = selected['name'] as String? ?? '';
        if (assetName.isEmpty) continue;
        newest = UpdateInfo(
          tag: tag,
          releaseUrl: url,
          assetName: assetName,
          assetUrl: assetUrl,
          digest: digest,
        );
      }
      if (!mounted) return;
      setState(() {
        _updateInfo = newest != null && _isNewerVersion(newest.tag, _appVersion) ? newest : null;
        _updateStatus = newest == null ? _tr('updateStatusNoRelease') : _updateInfo == null ? _tr('updateStatusCurrent') : _tr('updateStatusAvailable');
      });
      _addEvent('Bridge bağlantısı aktif');
    } catch (_) {
      if (mounted) setState(() => _updateStatus = _tr('updateStatusCheckFailed'));
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

  Future<void> _downloadVerifiedUpdate() async {
    final info = _updateInfo;
    if (info == null || _isCheckingUpdate) return;
    if (!info.assetUrl.startsWith('https://github.com/lordkeremello45/HWcontrol2.0/releases/download/')) return;
    try {
      setState(() {
        _isCheckingUpdate = true;
        _updateStatus = _tr('updateStatusDownloading');
      });
      final response = await http.get(Uri.parse(info.assetUrl)).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) throw StateError('update download failed');
      final bytes = response.bodyBytes;
      final actual = sha256.convert(bytes).toString();
      if (actual.toLowerCase() != info.digest.toLowerCase()) {
        throw StateError('SHA-256 doğrulaması başarısız');
      }
      final directory = await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final file = File('${directory.path}${Platform.pathSeparator}${info.assetName}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _updateStatus = AppLocalizations.of(context).updateStatusVerified(file.path));
      _addEvent('Release indirildi ve SHA-256 doğrulandı');
    } catch (error) {
      if (mounted) {
        setState(() => _updateStatus = AppLocalizations.of(context).updateStatusVerificationFailed('$error'));
        _addEvent('Release indirme/doğrulama başarısız');
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  Future<void> _openUpdate() async {
    final info = _updateInfo;
    if (info == null) return;
    final uri = Uri.parse(info.releaseUrl);
    if (!uri.isScheme('https') || uri.host != 'github.com') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSettingsMenu() async {
    var notificationsEnabled = _notificationsEnabled;
    var temperatureLimit = _temperatureLimit;
    var selectedLocale = _languagePreference;
    var selectedLanguageStyle = _languageStyle;
    var piperEnabled = _piperTtsEnabled;
    var piperStatus = '';
    final piperExecutableController = TextEditingController(text: _piperExecutablePath);
    final piperModelController = TextEditingController(text: _piperModelPath);
    try {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [const Icon(Icons.menu), const SizedBox(width: 10), Text(_tr('menu'))]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tr('language'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: selectedLocale,
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedLocale = value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_tr('systemDefault')),
                          subtitle: Text(HWControlLanguageService.systemLocaleCode),
                          value: HWControlLanguageService.systemDefault,
                        ),
                        for (final locale in _supportedLocales)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(locale['name'] ?? locale['code'] ?? ''),
                            value: locale['code'] ?? '',
                          ),
                      ],
                    ),
                  ),
                  if (selectedLocale == HWControlLanguageService.systemDefault
                      ? HWControlLanguageService.systemLocaleCode.toLowerCase().startsWith('tr')
                      : selectedLocale.toLowerCase().startsWith('tr')) ...[
                    const SizedBox(height: 8),
                    const Text('Dil üslubu', style: TextStyle(fontWeight: FontWeight.w700)),
                    RadioGroup<String>(
                      groupValue: selectedLanguageStyle,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedLanguageStyle = value);
                        }
                      },
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Standart Türkçe'),
                            subtitle: Text('Açık, doğrudan ve teknik anlatım'),
                            value: HWControlLocalizationStyleService.standard,
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Edebî Türkçe'),
                            subtitle: Text('Daha akıcı ve özenli anlatım'),
                            value: HWControlLocalizationStyleService.literary,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 22),
                  Text(_tr('accessibility'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_tr('offlineSpeech')),
                    subtitle: Text(_tr('piperOfflineDescription')),
                    value: piperEnabled,
                    onChanged: (value) => setDialogState(() => piperEnabled = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: piperExecutableController,
                          decoration: InputDecoration(
                            labelText: _tr('piperExecutablePath'),
                            hintText: Platform.isWindows ? r'C:\Tools\piper\piper.exe' : '/usr/local/bin/piper',
                          ),
                          autocorrect: false,
                        ),
                      ),
                      IconButton(
                        tooltip: _tr('browsePiperExecutable'),
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          final picked = await FilePicker.pickFiles(type: FileType.any);
                          final path = picked?.files.single.path;
                          if (path != null && path.isNotEmpty) {
                            piperExecutableController.text = path;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: piperModelController,
                          decoration: InputDecoration(
                            labelText: _tr('piperModelPath'),
                            hintText: 'voice.onnx',
                          ),
                          autocorrect: false,
                        ),
                      ),
                      IconButton(
                        tooltip: _tr('browsePiperModel'),
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          final picked = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['onnx'],
                          );
                          final path = picked?.files.single.path;
                          if (path != null && path.isNotEmpty) {
                            piperModelController.text = path;
                          }
                        },
                      ),
                    ],
                  ),
                  Text(_tr('piperModelConfigHint'), style: Theme.of(context).textTheme.bodySmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://github.com/OHF-Voice/piper1-gpl/releases'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(_tr('getPiperExecutable')),
                      ),
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.record_voice_over_outlined),
                        label: Text(_tr('piperVoiceCatalog')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          setDialogState(() => piperStatus = _tr('piperTesting'));
                          try {
                            await _piperTts.speak(
                              text: _tr('piperTestPhrase'),
                              executablePath: piperExecutableController.text,
                              modelPath: piperModelController.text,
                            );
                            setDialogState(() => piperStatus = _tr('piperTestSuccess'));
                          } catch (error) {
                            setDialogState(() => piperStatus = '${_tr('piperTestFailed')}: $error');
                          }
                        },
                        icon: const Icon(Icons.volume_up_outlined),
                        label: Text(_tr('testSpeech')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _piperTts.stop();
                          setDialogState(() => piperStatus = _tr('piperSpeechStopped'));
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(_tr('stopSpeech')),
                      ),
                      OutlinedButton.icon(
                        onPressed: piperEnabled
                            ? () async {
                                try {
                                  await _piperTts.speak(
                                    text: AppLocalizations.of(context).dashboardSpeechSummary(
                                      _cpuTemperature.toStringAsFixed(1),
                                      _cpuUsage.toStringAsFixed(0),
                                      _gpuUsage.toStringAsFixed(0),
                                    ),
                                    executablePath: piperExecutableController.text,
                                    modelPath: piperModelController.text,
                                  );
                                  setDialogState(() => piperStatus = _tr('piperTestSuccess'));
                                } catch (error) {
                                  setDialogState(() => piperStatus = '${_tr('piperTestFailed')}: $error');
                                }
                              }
                            : null,
                        icon: const Icon(Icons.accessibility_new),
                        label: Text(_tr('readDashboard')),
                      ),
                    ],
                  ),
                  if (piperStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Semantics(liveRegion: true, child: Text(piperStatus)),
                  ],
                  const Divider(height: 22),
                  Text(_tr('settings'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_tr('enableNotifications')),
                    value: notificationsEnabled,
                    onChanged: (value) => setDialogState(() => notificationsEnabled = value),
                  ),
                  Row(children: [
                    Expanded(child: Text(_tr('temperatureWarning'))),
                    Text('${temperatureLimit.round()} °C', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  ]),
                  Slider(
                    value: temperatureLimit, min: 60, max: 100, divisions: 16,
                    label: '${temperatureLimit.round()} °C',
                    onChanged: (value) => setDialogState(() => temperatureLimit = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_tr('cancel'))),
            FilledButton(
              onPressed: () async {
                // Capture the dialog navigator before awaiting; BuildContext must not
                // be reused across this asynchronous localization-style operation.
                final dialogNavigator = Navigator.of(context);
                final nextLocale = HWControlLanguageService.resolveLocale(
                  savedLocale: selectedLocale,
                  supportedCodes: AppLocalizations.supportedLocales.map(localeTag),
                );
                final baseTranslations =
                    lookupAppLocalizations(localeFromTag(nextLocale)).toStringMap();
                final nextTranslations =
                    await HWControlLocalizationStyleService.applyStyle(
                  localeCode: nextLocale,
                  style: selectedLanguageStyle,
                  translations: baseTranslations,
                );
                if (!mounted || !dialogNavigator.mounted) return;
                setState(() {
                  _notificationsEnabled = notificationsEnabled;
                  _temperatureLimit = temperatureLimit;
                  _languagePreference = selectedLocale;
                  _languageStyle = selectedLanguageStyle;
                  _piperTtsEnabled = piperEnabled;
                  _piperExecutablePath = piperExecutableController.text.trim();
                  _piperModelPath = piperModelController.text.trim();
                  _locale = nextLocale;
                  _translations = nextTranslations;
                });
                widget.onLocaleChanged(_locale);
                unawaited(_saveSettings());
                dialogNavigator.pop();
              },
              child: Text(_tr('save')),
            ),
          ],
        ),
      ),
    );
    } finally {
      piperExecutableController.dispose();
      piperModelController.dispose();
    }
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

  Future<bool> _sendCommand(String action, double value, {String? target}) async {
    if ((action == 'Fan Hızı' || action == 'Set Fan Channel') &&
        _emergencyCoolingActive &&
        value < 100) {
      if (mounted) {
        setState(() => _status = 'Acil soğutma etkin; sıcaklıklar 92 °C altına inene kadar fan hedefi düşürülemez');
      }
      return false;
    }
    if (action == 'Set Fan Channel' &&
        (target == null ||
            !_fanChannels.any((channel) => channel.id == target && channel.supported))) {
      if (mounted) {
        setState(() => _status = 'Fan kanalı artık kullanılabilir değil; donanım yeteneklerini yenileyin');
      }
      return false;
    }
    if (action != 'Set Fan Channel' && target != null) {
      if (mounted) setState(() => _status = 'Geçersiz hedefli komut');
      return false;
    }
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nonce = _commandNonce();
      final auth = _commandAuth(
        action: action,
        value: value,
        timestamp: timestamp,
        nonce: nonce,
        target: target,
      );
      final request = <String, dynamic>{
        'action': action,
        'value': value,
        'timestamp': timestamp,
        'nonce': nonce,
        'auth': auth,
      };
      if (target != null) request['target'] = target;
      socket.write('${jsonEncode(request)}\n');

      final responses = _responses;
      if (responses == null || !await responses.moveNext().timeout(const Duration(seconds: 3))) {
        throw StateError('Bridge response missing');
      }
      final response = jsonDecode(responses.current) as Map<String, dynamic>;
      if (!mounted) return false;
      final responseStatus = response['status'] as String? ?? 'ERROR';
      final responseData = response['data'];
      setState(() {
        _status = response['message'] as String? ?? 'Yanıt alındı';
        _lastAction = target == null ? '$action  •  %${value.round()}' : '$action  •  $target  •  %${value.round()}';
        if ((action == 'Get Power Mode' ||
                action == 'Set Power Mode AC' ||
                action == 'Set Power Mode DC') &&
            responseData is Map) {
          final supported = responseData['supported'] == true;
          final ac = responseData['ac']?.toString() ?? 'Unknown';
          final dc = responseData['dc']?.toString() ?? 'Unknown';
          _osPowerModeStatus = supported
              ? 'AC: $ac  •  Battery: $dc'
              : (responseData['message']?.toString() ?? 'OS power mode unsupported');
        }
      });
      return responseStatus == 'SUCCESS';
    } catch (_) {
      if (!mounted) return false;
      setState(() => _status = 'Bridge yanıt vermedi');
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _playGameModeSound(bool enabled) async {
    // Short, locally synthesized gamer-style UI sound. No external audio
    // asset or network request is required; mode changes still work silently
    // if the platform audio backend is unavailable.
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

  Future<void> _togglePerformanceMode() async {
    final enabling = !_performanceModeEnabled;
    if (enabling) {
      _prePerformanceFanValue = _fanValue;
      _prePerformanceAiValue = _aiValue;
    }
    setState(() {
      _performanceModeEnabled = enabling;
      _performanceLabOpen = enabling;
      _fanValue = enabling ? 85 : _prePerformanceFanValue;
      _aiValue = enabling ? 100 : _prePerformanceAiValue;
      _lastAction = enabling
          ? 'Performance Mode: application preset selected; OS capabilities unchanged'
          : 'Performance Mode disabled; previous application targets restored';
    });

    // This applies only the app's existing preset and supported fan command.
    // It does not claim to overclock or alter OS power settings.
    if (!_isSending) {
      if (enabling) {
        await _applyPreset('Performance', 'performance', 85, 100);
      } else if (_fanControlSupported) {
        await _sendCommand('Fan Hızı', _prePerformanceFanValue);
      }
    }
    await _playGameModeSound(enabling);
    if (mounted) {
      _addEvent(enabling
          ? 'Performance Mode etkinleştirildi'
          : 'Performance Mode devre dışı bırakıldı');
    }
  }

  Future<void> _applyPreset(String name, String legacyProfileName, double fan, double ai) async {
    if (_isSending) return;
    setState(() {
      _fanValue = fan;
      _aiValue = ai;
      _lastAction = '$name profili hazırlanıyor';
    });
    final savedProfile = _profiles[legacyProfileName] ?? _profiles[name];
    if (savedProfile != null) {
      fan = savedProfile['fan'] ?? fan;
      ai = savedProfile['ai'] ?? ai;
      setState(() { _fanValue = fan; _aiValue = ai; });
    }
    if (_fanControlSupported) {
      await _sendCommand('Fan Hızı', fan);
    }
    if (mounted) {
      setState(() => _lastAction =
          '$name profili  •  fan %${fan.round()}  •  AI analiz seviyesi %${ai.round()}');
    }
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
    unawaited(_piperTts.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: HWControlLanguageService.isRightToLeft(_locale)
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: AnimatedTheme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _performanceModeEnabled
                ? const Color(0xFFFF334F)
                : const Color(0xFF4F8CFF),
            secondary: _performanceModeEnabled
                ? const Color(0xFFFF7954)
                : const Color(0xFF75B7FF),
          ),
        ),
        duration: widget.animationsEnabled
            ? const Duration(milliseconds: 900)
            : Duration.zero,
        child: Scaffold(
          backgroundColor: _performanceModeEnabled
              ? const Color(0xFF130B10)
              : null,
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
                      const SizedBox(height: 14),
                      _buildPerformanceModeActions(),
                      if (_performanceLabOpen) ...[
                        const SizedBox(height: 18),
                        _buildPerformanceLab(),
                      ],
                      const SizedBox(height: 28),
                      _buildUpdateCard(),
                      const SizedBox(height: 18),
                      _buildOverview(compact),
                      const SizedBox(height: 18),
                      _buildBatteryHealthCard(),
                      const SizedBox(height: 18),
                      _buildHealthyCoreCard(),
                      const SizedBox(height: 18),
                      _buildHistoryCard(),
                      const SizedBox(height: 18),
                      _buildAdvancedTelemetryCard(),
                      const SizedBox(height: 18),
                      _buildAiAnalysisCard(),
                      const SizedBox(height: 18),
                      _buildHardwareIdentityCard(),
                      const SizedBox(height: 18),
                      _buildStorageCard(),
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
        ),
      ),
    );
  }

  Widget _buildPerformanceModeActions() {
    final activeColor = _performanceModeEnabled
        ? const Color(0xFFFF334F)
        : const Color(0xFF4F8CFF);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: _isSending ? null : _togglePerformanceMode,
          icon: Icon(_performanceModeEnabled ? Icons.bolt : Icons.speed),
          label: Text(_performanceModeEnabled
              ? 'Performance Mode: ON'
              : 'Enable Performance Mode'),
          style: FilledButton.styleFrom(
            backgroundColor: activeColor,
            foregroundColor: Colors.white,
          ),
        ),
        if (_performanceModeEnabled)
          OutlinedButton.icon(
            onPressed: () => setState(() => _performanceLabOpen = !_performanceLabOpen),
            icon: Icon(_performanceLabOpen ? Icons.keyboard_arrow_up : Icons.tune),
            label: Text(_performanceLabOpen ? 'Hide Performance Lab' : 'Open Performance Lab'),
          ),
        Text(
          _performanceModeEnabled
              ? 'App preset active • OS / overclock controls not applied'
              : 'Application-level preset; hardware support is capability-gated',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceLab() {
    final accent = Theme.of(context).colorScheme.primary;
    return _Panel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: accent, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Performance Lab', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Advanced controls • capability-gated', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close Performance Lab',
                onPressed: () => setState(() => _performanceLabOpen = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(70)),
            ),
            child: const Text(
              'Performance Mode currently selects HWcontrol’s app-level Performance preset. It does not unlock extra CPU/GPU power by itself. Firmware limits, thermal protection, OS policy, and hardware capabilities remain authoritative.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          _performanceCapabilityTile(
            icon: Icons.sports_esports,
            title: 'Prioritize the active game',
            status: 'NOT IMPLEMENTED',
            description: 'Per-process priority and background-process policy need a verified native adapter. No process priority is changed yet.',
          ),
          const Divider(height: 24),
          _performanceCapabilityTile(
            icon: Icons.memory,
            title: 'Per-application RAM budget (GiB)',
            status: 'NOT IMPLEMENTED',
            description: 'A desktop app cannot safely reserve arbitrary RAM for unrelated apps through a generic cross-platform API. A future implementation must define supported process/job limits and show the effective limit instead of pretending RAM was allocated.',
          ),
          const Divider(height: 24),
          _performanceCapabilityTile(
            icon: Icons.speed,
            title: 'CPU/GPU overclocking and power limits',
            status: 'NOT IMPLEMENTED',
            description: 'No generic cross-platform overclock is safe or reliable. Any future adapter must be vendor/device-specific, opt-in, bounded, read back the applied values, and never disable thermal protection.',
          ),
          const Divider(height: 24),
          _performanceCapabilityTile(
            icon: Icons.electric_bolt,
            title: 'Operating-system power mode',
            status: Platform.isWindows
                ? 'WINDOWS 11 ADAPTER'
                : (Platform.isLinux
                    ? 'LINUX ADAPTER'
                    : (Platform.isMacOS ? 'MANUAL • MODEL-DEPENDENT' : 'NOT IMPLEMENTED')),
            description: Platform.isMacOS
                ? 'Apple power modes depend on the exact Mac model, chip, macOS version, and power source. HWcontrol does not invoke undocumented controls; use Apple’s supported System Settings interface.'
                : 'Supported Windows 11 and Linux adapters can request and read back an OS power profile. The app-level Performance toggle does not silently change the OS power profile.',
          ),
          const SizedBox(height: 18),
          Text(
            Platform.isMacOS
                ? 'macOS power mode'
                : (Platform.isLinux ? 'Linux system power profile' : 'Windows 11 OS power mode'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            (Platform.isWindows || Platform.isLinux)
                ? _osPowerModeStatus
                : (Platform.isMacOS
                    ? 'Automatic switching is not implemented. Availability is controlled by Apple and varies by Mac model and macOS release.'
                    : 'Automated OS power-mode control is unavailable on this platform.'),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(175)),
          ),
          if (Platform.isLinux) ...[
            const SizedBox(height: 12),
            const Text('Linux system power profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Uses power-profiles-daemon when installed. Linux has one active system profile; this does not independently configure AC and battery.',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(160)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isSending ? null : () => _sendCommand('Get Power Mode', 0),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Read current Linux profile'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Profile', 50),
                  child: const Text('Power Saver'),
                ),
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Profile', 0),
                  child: const Text('Balanced'),
                ),
                FilledButton.tonal(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Profile', 100),
                  child: const Text('Performance'),
                ),
              ],
            ),
          ],
          if (Platform.isMacOS) ...[
            const SizedBox(height: 12),
            const Text(
              'Apple-supported power modes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Open Apple’s official guide to check whether Low Power Mode or High Power Mode is supported by this Mac. HWcontrol will not change hidden or undocumented power settings.',
              style: TextStyle(fontSize: 11, height: 1.45),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openMacPowerModeGuide,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Apple power-mode guide'),
            ),
          ],
          if (Platform.isWindows) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSending ? null : () => _sendCommand('Get Power Mode', 0),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Read current OS power modes'),
            ),
            const SizedBox(height: 10),
            const Text('Plugged in (AC)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode AC', 0),
                  child: const Text('Balanced'),
                ),
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode AC', 50),
                  child: const Text('Efficiency'),
                ),
                FilledButton.tonal(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode AC', 100),
                  child: const Text('Performance'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('On battery (DC)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode DC', 0),
                  child: const Text('Balanced'),
                ),
                OutlinedButton(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode DC', 50),
                  child: const Text('Efficiency'),
                ),
                FilledButton.tonal(
                  onPressed: _isSending ? null : () => _sendCommand('Set Power Mode DC', 100),
                  child: const Text('Performance'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Each action changes only the selected power-source setting. Windows may override effective performance; selecting Performance does not overclock the CPU/GPU.',
              style: TextStyle(fontSize: 11, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Available now: the app preset and fan target only when the bridge reports fan-control support. Actual performance gains remain unverified.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
          ),
        ],
      ),
    );
  }

  Future<void> _openMacPowerModeGuide() async {
    final uri = Uri.parse('https://support.apple.com/en-us/101613');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _performanceCapabilityTile({
    required IconData icon,
    required String title,
    required String status,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(fontSize: 12, height: 1.45, color: Theme.of(context).colorScheme.onSurface.withAlpha(185))),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openAudioControllerStudio() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => AudioControllerStudioScreen(onRecommend: _requestLocalAudioProfile, onLoadDevices: () => _requestBridgeData('Get Audio Devices'), onControl: _requestAudioStudioControl)),
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
              Text(_tr('appTagline'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(140), fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: widget.darkMode ? _tr('lightMode') : _tr('darkMode'),
          onPressed: () => widget.onThemeChanged(!widget.darkMode),
          icon: Icon(widget.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        IconButton(
          tooltip: widget.animationsEnabled ? _tr('animationsOn') : _tr('animationsOff'),
          onPressed: () => widget.onAnimationsChanged(!widget.animationsEnabled),
          icon: Icon(widget.animationsEnabled ? Icons.animation : Icons.animation_outlined),
        ),
        IconButton(tooltip: 'Audio Controller Studio', onPressed: _openAudioControllerStudio, icon: const Icon(Icons.graphic_eq)),
        IconButton(tooltip: _tr('menu'), onPressed: _openSettingsMenu, icon: const Icon(Icons.menu)),
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
            Text(_isConnected ? _tr('online') : _tr('offline'), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard() {
    final updateInfo = _updateInfo;
    final available = updateInfo != null;
    final color = available ? const Color(0xFFFFB454) : const Color(0xFF64D8CB);
    return AnimatedSwitcher(
      duration: widget.animationsEnabled ? const Duration(milliseconds: 220) : Duration.zero,
      child: _Panel(
        key: ValueKey('$_updateStatus-${updateInfo?.tag}'),
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
            Icon(available ? Icons.system_update_alt : Icons.verified_user_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(available ? AppLocalizations.of(context).updateReleaseReady(updateInfo.tag) : (_updateStatus.isEmpty ? _tr('updateStatusNotChecked') : _updateStatus), style: TextStyle(color: color, fontWeight: FontWeight.w600))),
            if (available) TextButton.icon(onPressed: _openUpdate, icon: const Icon(Icons.download, size: 17), label: Text(_tr('releaseOpen'))),
            IconButton(tooltip: _tr('checkForUpdates'), onPressed: _isCheckingUpdate ? null : _checkForUpdate, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(bool compact) {
    final cards = [
      _MetricData(_tr('cpuTemperatureLabel'), _cpuTemperature.toStringAsFixed(1), '°C', Icons.thermostat, const Color(0xFFFFB454), (_cpuTemperature / 100).clamp(0, 1)),
      _MetricData(_tr('cpuUsageLabel'), _cpuUsage.toStringAsFixed(0), '%', Icons.memory, const Color(0xFF64D8CB), (_cpuUsage / 100).clamp(0, 1)),
      _MetricData(_tr('ramUsage'), _memoryUsage.toStringAsFixed(0), '%', Icons.storage, const Color(0xFF8FA7FF), (_memoryUsage / 100).clamp(0, 1)),
      _MetricData(_tr('diskUsage'), _diskUsage.toStringAsFixed(0), '%', Icons.save, const Color(0xFFB995FF), (_diskUsage / 100).clamp(0, 1)),
      _MetricData(_tr('gpuUsage'), _gpuUsage.toStringAsFixed(0), '%', Icons.graphic_eq, const Color(0xFFFF8C69), (_gpuUsage / 100).clamp(0, 1)),
      _MetricData(_tr('fan'), _fanRpm > 0 ? _fanRpm.toStringAsFixed(0) : _fanPercent.toStringAsFixed(0), _fanRpm > 0 ? 'RPM' : '%', Icons.air, const Color(0xFF64D8CB), (_fanRpm > 0 ? _fanRpm / 3000 : _fanPercent / 100).clamp(0, 1)),
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

  Widget _buildBatteryHealthCard() {
    final health = _batteryHealthPercent;
    final healthKnown = _batteryPresent && _batteryDataAvailable && health.isFinite && health > 0;
    final healthColor = !healthKnown
        ? Theme.of(context).colorScheme.onSurface.withAlpha(120)
        : health >= 80
            ? const Color(0xFF64D8CB)
            : health >= 60
                ? const Color(0xFFFFB454)
                : const Color(0xFFFF6B6B);
    final wear = _batteryDesignCapacity > 0 && _batteryFullChargeCapacity > 0
        ? (_batteryDesignCapacity - _batteryFullChargeCapacity).clamp(0, double.infinity).toDouble()
        : 0.0;
    final statusLabel = switch (_batteryStatus.toLowerCase()) {
      'charging' || 'charging-high' || 'charging-low' || 'charging-critical' => _tr('batteryCharging'),
      'discharging' => _tr('batteryDischarging'),
      'full' => _tr('batteryFull'),
      'ac-connected' => _tr('batteryConnected'),
      'unavailable' || 'unsupported' => _tr('batteryDataUnavailable'),
      _ => _tr('batteryUnknownStatus'),
    };
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_5_bar, color: healthColor, size: 25),
              const SizedBox(width: 10),
              Expanded(child: _sectionTitle(_tr('batteryHealth'), _tr('batteryHealthDescription'))),
              Text(healthKnown ? '${health.toStringAsFixed(0)}%' : 'N/A',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: healthColor)),
            ],
          ),
          const SizedBox(height: 16),
          if (!_batteryPresent)
            Text(_tr('batteryNotDetected'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(170)))
          else if (!_batteryDataAvailable)
            Text(_tr('batteryDataUnavailable'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(170)))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: (health / 100).clamp(0, 1), minHeight: 8, color: healthColor),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _telemetryChip(_tr('batteryDesignCapacity'), '${_batteryDesignCapacity.toStringAsFixed(0)} $_batteryCapacityUnit'),
                _telemetryChip(_tr('batteryFullChargeCapacity'), '${_batteryFullChargeCapacity.toStringAsFixed(0)} $_batteryCapacityUnit'),
                _telemetryChip(_tr('batteryCapacityWear'), '${wear.toStringAsFixed(0)} $_batteryCapacityUnit'),
                _telemetryChip(_tr('batteryCycleCount'), _batteryCycleCount == null ? 'N/A' : '$_batteryCycleCount'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_tr('batteryStatusLabel')}: $statusLabel',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(170)),
            ),
          ],
          const SizedBox(height: 8),
          Text(_tr('batteryHealthCaveat'),
            style: TextStyle(fontSize: 11, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withAlpha(130))),
        ],
      ),
    );
  }

  Widget _buildHealthyCoreCard() {
    // This is an operational thermal-condition indicator, not a measurement
    // of physical silicon wear or remaining useful life.
    final cpuSamples = _history.where((sample) => sample.cpuTemperature.isFinite && sample.cpuTemperature > 0 && sample.cpuTemperature <= 125).toList(growable: false);
    final gpuSamples = _history.where((sample) => sample.gpuTemperature.isFinite && sample.gpuTemperature > 0 && sample.gpuTemperature <= 125).toList(growable: false);
    int? evaluate(List<_MetricSample> samples, bool cpu) {
      if (samples.length < 12) return null;
      final threshold = cpu ? 85.0 : 80.0;
      final temperatures = samples.map((sample) => cpu ? sample.cpuTemperature : sample.gpuTemperature).toList(growable: false);
      final maximum = temperatures.reduce((a, b) => a > b ? a : b);
      final hotCount = temperatures.where((value) => value >= threshold).length;
      final hotRatio = hotCount / temperatures.length;
      var score = 100;
      if (maximum >= threshold + 10) {
        score -= 25;
      } else if (maximum >= threshold + 5) {
        score -= 15;
      } else if (maximum >= threshold) {
        score -= 8;
      }
      if (hotRatio >= 0.5) {
        score -= 25;
      } else if (hotRatio >= 0.2) {
        score -= 15;
      } else if (hotRatio >= 0.05) {
        score -= 7;
      }
      return score.clamp(0, 100).toInt();
    }

    final cpuScore = evaluate(cpuSamples, true);
    final gpuScore = evaluate(gpuSamples, false);
    final hasData = cpuScore != null || gpuScore != null;
    final colorFor = (int? score) => score == null
        ? Theme.of(context).colorScheme.onSurface.withAlpha(120)
        : score >= 85
            ? const Color(0xFF64D8CB)
            : score >= 65
                ? const Color(0xFFFFB454)
                : const Color(0xFFFF6B6B);
    Widget scoreRow(String label, int? score, int count, IconData icon) {
      final color = colorFor(score);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withAlpha(110),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 7),
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(180)))),
              ]),
              const SizedBox(height: 8),
              Text(score == null ? 'N/A' : '$score/100',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(score == null ? '12+ örnek bekleniyor' : '$count ölçüm',
                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withAlpha(130))),
              if (score != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(value: score / 100, minHeight: 5, color: color),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final cpuMaximum = cpuSamples.isEmpty ? null : cpuSamples.map((sample) => sample.cpuTemperature).reduce((a, b) => a > b ? a : b);
    final gpuMaximum = gpuSamples.isEmpty ? null : gpuSamples.map((sample) => sample.gpuTemperature).reduce((a, b) => a > b ? a : b);
    final subtitle = !hasData
        ? 'Gerçek telemetri toplanıyor; puan için her aygıtta en az 12 geçerli sıcaklık örneği gerekir.'
        : 'Bu puan yalnızca gözlenen termal koşulları özetler; fiziksel yıpranma yüzdesi veya kalan ömür değildir.';
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.health_and_safety_outlined, size: 25, color: Color(0xFF64D8CB)),
            const SizedBox(width: 10),
            Expanded(child: _sectionTitle('Healthy Core', 'CPU ve GPU termal sağlık göstergesi')),
            Text(hasData ? 'CANLI' : 'VERİ BEKLENİYOR',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7,
                color: hasData ? const Color(0xFF64D8CB) : Theme.of(context).colorScheme.onSurface.withAlpha(130))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            scoreRow('CPU', cpuScore, cpuSamples.length, Icons.memory),
            const SizedBox(width: 12),
            scoreRow('GPU', gpuScore, gpuSamples.length, Icons.developer_board),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            if (cpuMaximum != null) _telemetryChip('CPU en yüksek', '${cpuMaximum.toStringAsFixed(1)} °C'),
            if (gpuMaximum != null) _telemetryChip('GPU en yüksek', '${gpuMaximum.toStringAsFixed(1)} °C'),
            _telemetryChip('Geçmiş', '${_history.length}/720 örnek'),
          ]),
          const SizedBox(height: 12),
          // RAM utilization is not a RAM-wear measurement. Display it as
          // operational context while hardware error telemetry is unavailable.
          Builder(builder: (context) {
            final validRam = _history
                .map((sample) => sample.memoryUsage)
                .where((value) => value.isFinite && value >= 0 && value <= 100)
                .toList(growable: false);
            final ramAvailable = validRam.length >= 1;
            final ramPeak = ramAvailable ? validRam.reduce((a, b) => a > b ? a : b) : 0.0;
            final ramCurrentValid = _memoryUsage.isFinite && _memoryUsage >= 0 && _memoryUsage <= 100;
            final ramCurrent = ramCurrentValid ? _memoryUsage : (ramAvailable ? validRam.last : 0.0);
            final ramColor = !ramAvailable
                ? Theme.of(context).colorScheme.onSurface.withAlpha(120)
                : ramCurrent >= 90
                    ? const Color(0xFFFF6B6B)
                    : ramCurrent >= 75
                        ? const Color(0xFFFFB454)
                        : const Color(0xFF64D8CB);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withAlpha(110),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ramColor.withAlpha(65)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.memory, color: ramColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('RAM bellek gözlemi', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('SAĞLIK: BİLİNMİYOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                  ]),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(ramAvailable ? '${ramCurrent.toStringAsFixed(1)}%' : 'N/A',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ramColor)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('mevcut RAM kullanımı', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                    ),
                    const Spacer(),
                    if (ramAvailable) Text('Zirve: ${ramPeak.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                  ]),
                  if (ramAvailable) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(value: ramCurrent / 100, minHeight: 5, color: ramColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    ramAvailable
                        ? 'Bellek kullanım oranı gösterilir; yüksek kullanım tek başına RAM arızası veya yıpranması anlamına gelmez. ECC/donanım hata sayaçları henüz bu ekrana bağlanmadı.'
                        : 'RAM kullanım verisi henüz mevcut değil. Sağlık puanı üretilmiyor; ECC ve donanım hata sayaçları desteklenirse ayrıca değerlendirilecek.',
                    style: TextStyle(fontSize: 10, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withAlpha(145)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(subtitle, style: TextStyle(fontSize: 11, height: 1.45, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
          const SizedBox(height: 6),
          Text('Eşikler genel uyarı eşikleridir; modele özgü üretici sınırlarının yerine geçmez. Sensör verisi olmayan aygıt için puan üretilmez.',
            style: TextStyle(fontSize: 10, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
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
              Expanded(child: _sectionTitle(_tr('telemetryHistory'), _tr('samplingInterval'))),
              Text(AppLocalizations.of(context).maxCpuTemperature(maximum), style: const TextStyle(color: Color(0xFFFFB454), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              IconButton(tooltip: _tr('exportCsv'), onPressed: _history.isEmpty ? null : _exportTelemetryHistory, icon: const Icon(Icons.download_outlined, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).thermalStatus(_thermalStatus), style: TextStyle(fontSize: 11, color: _thermalAlertActive ? const Color(0xFFFFB454) : Theme.of(context).colorScheme.onSurface.withAlpha(140))),
          const SizedBox(height: 14),
          if (_history.isEmpty)
            SizedBox(height: 130, child: Center(child: Text(_tr('bridgeMetricsWaiting'), style: TextStyle(color: Colors.white54, fontSize: 12))))
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
          _sectionTitle(_tr('advancedTelemetry'), _tr('advancedTelemetryDescription')),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _telemetryChip('GPU', '${_gpuUsage.toStringAsFixed(0)}%'),
              _telemetryChip(_tr('vramUsageLabel'), '${_gpuMemoryUsage.toStringAsFixed(0)}%'),
              _telemetryChip(_tr('power'), '${_gpuPowerWatts.toStringAsFixed(1)} W'),
              _telemetryChip(_tr('gpuPowerLimit'), _gpuPowerLimitWatts > 0 ? '${_gpuPowerLimitWatts.toStringAsFixed(1)} W' : 'N/A'),
              _telemetryChip(_tr('coreClock'), _gpuCoreClockMHz > 0 ? '${_gpuCoreClockMHz.toStringAsFixed(0)} MHz' : 'N/A'),
              _telemetryChip(_tr('memoryClock'), _gpuMemoryClockMHz > 0 ? '${_gpuMemoryClockMHz.toStringAsFixed(0)} MHz' : 'N/A'),
              _telemetryChip(_tr('gpuState'), _gpuPState),
              _telemetryChip(_tr('gpuEncoder'), '${_gpuEncoderUsage.toStringAsFixed(0)}%'),
              _telemetryChip(_tr('gpuDecoder'), '${_gpuDecoderUsage.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 16),
          if (hasGpuTelemetry)
            LinearProgressIndicator(value: (_gpuPowerLimitWatts > 0 ? _gpuPowerWatts / _gpuPowerLimitWatts : _gpuUsage / 100).clamp(0, 1), minHeight: 4)
          else
            Text(_tr('gpuTelemetryNote'), style: const TextStyle(fontSize: 12)),
          if (_cpuPerCoreUsage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_tr('cpuCoreLoad'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
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
              Expanded(child: _sectionTitle(_tr('aiAnalysis'), _tr('localAiAnalysisDescription'))),
              OutlinedButton.icon(
                onPressed: _aiSending || _aiStarting || _aiModelDownloading
                    ? null
                    : () async {
                        final data = await _requestBridgeData('Get Status');
                        if (data != null) {
                          unawaited(_requestAiAnalysis(data, force: true));
                        }
                      },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(_tr('runAiAnalysis')),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _tr('clearAiModelCache'),
                onPressed: _aiSending || _aiStarting || _aiModelDownloading || _aiProcess != null
                    ? null
                    : () async {
                        try {
                          await HWControlModelManager.removeCachedModel();
                          if (!mounted) return;
                          setState(() {
                            _aiAnalysis = 'Model cache temizlendi; sonraki analizde yeniden indirilir.';
                            _aiAnalysisTime = null;
                            _aiStatus = 'AI modeli hazır değil';
                            _aiModelError = null;
                          });
                        } catch (error) {
                          if (mounted) {
                            setState(() => _aiStatus = 'Model cache temizlenemedi: $error');
                          }
                        }
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'AI modeli isteğe bağlıdır; bu panelden açıkça çalıştırılmadıkça indirilmez veya yüklenmez.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(130)),
          ),
          const SizedBox(height: 14),
          if (_aiModelDownloading) ...[
            LinearProgressIndicator(value: _aiModelProgress),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).modelDownloading((_aiModelProgress * 100).round()), style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 12),
          ],
          if (_aiModelError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              child: Text(_aiModelError!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
            const SizedBox(height: 10),
          ],
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
              Text(_tr('llmControlUnavailable'), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildStorageCard() {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_tr('storageTitle'), _tr('storageDescription')),
          const SizedBox(height: 18),
          if (_storageVolumes.isEmpty)
            Text(_tr('storageUnavailable'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)))
          else
            ..._storageVolumes.map(_storageVolumeTile),
        ],
      ),
    );
  }

  Widget _storageVolumeTile(Map<String, dynamic> volume) {
    final mount = (volume['mountPoint'] as String?)?.trim();
    final device = (volume['device'] as String?)?.trim();
    final fs = (volume['fileSystem'] as String?)?.trim();
    final rawDeviceType = (volume['deviceType'] as String?) ?? 'unknown';
    final deviceType = switch (rawDeviceType) {
      'nvme_ssd' => 'NVMe SSD',
      'usb_storage' => 'USB storage',
      'sd_card' => 'SD card (SD/microSD not distinguishable)',
      'mmc_storage' => 'MMC storage (media type unknown)',
      'removable_storage' => 'Removable storage',
      'hdd' => 'HDD',
      'ssd' => 'SSD',
      _ => 'Media type unknown',
    };
    final removable = (volume['removable'] as bool?) ?? false;
    final usage = (volume['usagePercent'] as num?)?.toDouble() ?? 0;
    final free = (volume['freeBytes'] as num?)?.toInt() ?? 0;
    final read = (volume['readBytesPerSec'] as num?)?.toDouble() ?? 0;
    final write = (volume['writeBytesPerSec'] as num?)?.toDouble() ?? 0;
    final health = (volume['healthPercent'] as num?)?.toDouble();
    final healthStatus = (volume['healthStatus'] as String?) ?? 'unknown';
    final healthReason = (volume['healthReason'] as String?) ?? '';
    String bytes(int value) {
      const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
      double size = value.toDouble();
      var index = 0;
      while (size >= 1024 && index < units.length - 1) {
        size /= 1024;
        index++;
      }
      return '${size.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
    }
    String rate(double value) {
      return '${bytes(value.round())}/s';
    }
    final title = (mount == null || mount.isEmpty) ? (device ?? 'Storage') : mount;
    final usageColor = usage >= 95 ? const Color(0xFFFF7B7B) : usage >= 85 ? const Color(0xFFFFB454) : const Color(0xFF64D8CB);
    final healthText = health == null ? healthStatus : '${health.toStringAsFixed(0)}%';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, color: usageColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              Text('${usage.toStringAsFixed(1)}%', style: TextStyle(color: usageColor, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (usage / 100).clamp(0, 1), minHeight: 5),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(deviceType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              if (removable) const Text('Removable', style: TextStyle(fontSize: 11)),
              Text(AppLocalizations.of(context).freeSpace(bytes(free)),  style: const TextStyle(fontSize: 11)),
              Text(AppLocalizations.of(context).readSpeed(rate(read)),  style: const TextStyle(fontSize: 11)),
              Text(AppLocalizations.of(context).writeSpeed(rate(write)),  style: const TextStyle(fontSize: 11)),
              Text(AppLocalizations.of(context).health(healthText),  style: const TextStyle(fontSize: 11)),
              if (fs != null && fs.isNotEmpty) Text(AppLocalizations.of(context).fileSystem(fs),  style: const TextStyle(fontSize: 11)),
            ],
          ),
          if (health == null && healthReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(healthReason, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
          ],
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
          _sectionTitle(_tr('hardwareDetection'), _tr('hardwareDetectionDescription')),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _hardwareIdentityTile(Icons.computer_outlined, 'PC', '$_systemManufacturer $_systemModel'),
              _hardwareIdentityTile(Icons.developer_board_outlined, _tr('motherboardLabel'), '$_motherboardVendor $_motherboardModel'),
              _hardwareIdentityTile(Icons.memory_outlined, 'CPU', '$_cpuManufacturer $_cpuModel'),
              _hardwareIdentityTile(Icons.videogame_asset_outlined, 'GPU', '$_gpuVendor • $_gpuModel'),
              _hardwareIdentityTile(Icons.dns_outlined, 'BIOS', _biosVersion),
              _hardwareIdentityTile(Icons.drive_file_rename_outline, _tr('gpuDriverLabel'), _gpuDriver),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: detected ? const Color(0xFF64D8CB) : const Color(0xFFFFB454)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).diagnosticPrivacy(_hardwareDetectionStatus), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hardwareIdentityTile(IconData icon, String label, String value) {
    final text = value.trim().isEmpty ? _tr('unknown') : value.trim();
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
            _sectionTitle(_tr('gameMode'), _tr('gameModeDescription')),
            const SizedBox(height: 8),
            Text(_gameDetected ? AppLocalizations.of(context).detectedGame(_gameProcessName.isEmpty ? _tr('unknown') : _gameProcessName) : (_gameModeEnabled ? _tr('gameModeWaiting') : _tr('gameModeOff')), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(170))),
            const SizedBox(height: 4),
            Text(active ? _tr('activeGameProcess') : _tr('hardwareControlMonitorOnly'), style: TextStyle(fontSize: 11, color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withAlpha(130))),
          ])),
          if (_gameDetected)
            IconButton(
              tooltip: _tr('gameMode'),
              onPressed: _isSending ? null : _openGameProfileManager,
              icon: const Icon(Icons.tune),
            ),
          Tooltip(message: _tr('gameModeSet'), child: Switch(value: _gameModeEnabled, onChanged: _isSending ? null : (enabled) async {
            final success = await _sendCommand('Set Game Mode', enabled ? 100 : 0);
            if (!mounted) return;
            if (success) {
              setState(() => _gameModeEnabled = enabled);
              await _playGameModeSound(enabled);
              if (mounted) _addEvent(enabled ? 'Game Mode etkinleştirildi' : 'Game Mode devre dışı bırakıldı');
            }
          })),
        ],
      ),
    );
  }
  Future<void> _applyFanChannelPreset(String presetKey) async {
    final supportedChannels = _fanChannels
        .where((channel) => channel.supported && channel.id.isNotEmpty)
        .toList(growable: false);
    if (supportedChannels.isEmpty) return;

    final curve = fanCurvePreset(presetKey).normalized();
    setState(() {
      _fanCurve = curve;
      _smartFanEnabled = true;
      for (final channel in supportedChannels) {
        final profile = _profileForFanChannel(channel);
        _fanChannelProfiles[channel.id] = profile.copyWith(
          curve: curve,
          automaticEnabled: true,
        );
      }
    });
    await _persistFanCurves();
    unawaited(_saveSettings());
    _addEvent(
      _feedbackText(
        '${_presetNameForFanCurve(presetKey)} eğrisi tüm desteklenen fan kanallarına uygulandı',
        '${_presetNameForFanCurve(presetKey)} curve applied to all supported fan channels',
      ),
    );
  }

  String _presetNameForFanCurve(String presetKey) {
    switch (presetKey) {
      case 'quiet':
        return _tr('quiet');
      case 'performance':
        return _tr('performance');
      case 'balanced':
      default:
        return _tr('balanced');
    }
  }

  Future<void> _openFanChannelCurveEditor(FanChannelTelemetry channel) async {
    final profile = _profileForFanChannel(channel);
    await showDialog<void>(
      context: context,
      builder: (context) => FanCurveEditor(
        translations: _translations,
        initialCurve: profile.curve,
        onSave: (curve) {
          _updateFanChannelProfile(channel.id, profile.copyWith(curve: curve));
          _addEvent('${channel.name}: fan eğrisi kaydedildi');
        },
      ),
    );
  }

  Future<void> _applyFanChannelManualTarget(
    FanChannelTelemetry channel,
    double target,
  ) async {
    final safeTarget = target.clamp(20, 100).toDouble();
    final success = await _sendCommand(
      'Set Fan Channel',
      safeTarget,
      target: channel.id,
    );
    if (!success) return;

    final profile = _profileForFanChannel(channel);
    _updateFanChannelProfile(
      channel.id,
      profile.copyWith(
        manualPercent: safeTarget,
        automaticEnabled: false,
      ),
    );
    _addEvent('${channel.name}: manuel fan hedefi ${safeTarget.round()}% uygulandı');
  }

  Widget _buildFanChannelsPanel() {
    if (_fanChannels.isEmpty) return const SizedBox.shrink();
    final controllableCount = _fanChannels.where((channel) => channel.supported).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _feedbackText('Bağımsız fan kanalları', 'Independent fan channels'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$controllableCount / ${_fanChannels.length}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _feedbackText(
            'Her kanalın eğrisi ve sıcaklık kaynağı ayrı ayarlanabilir. Kontrol yalnızca köprünün desteklediği kanallarda açılır.',
            'Each channel has its own curve and temperature source. Control is enabled only for channels the bridge reports as supported.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isSending ? null : () => _applyFanChannelPreset('quiet'),
              icon: const Icon(Icons.volume_down_outlined, size: 16),
              label: Text(_tr('quiet')),
            ),
            OutlinedButton.icon(
              onPressed: _isSending ? null : () => _applyFanChannelPreset('balanced'),
              icon: const Icon(Icons.tune, size: 16),
              label: Text(_tr('balanced')),
            ),
            OutlinedButton.icon(
              onPressed: _isSending ? null : () => _applyFanChannelPreset('performance'),
              icon: const Icon(Icons.speed, size: 16),
              label: Text(_tr('performance')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final channel in _fanChannels) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.toys_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channel.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        channel.supported ? Icons.check_circle_outline : Icons.visibility_outlined,
                        color: channel.supported
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${channel.rpmAvailable ? '${channel.fanRpm.round()} RPM' : _feedbackText('RPM verisi yok', 'RPM unavailable')}'
                    '  •  '
                    '${channel.percentAvailable ? '${channel.fanPercent.round()}%' : _feedbackText('Hedef bilinmiyor', 'Duty unknown')}'
                    '  •  ${channel.backend}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!channel.supported) ...[
                    const SizedBox(height: 8),
                    Text(
                      channel.reason.isEmpty
                          ? _feedbackText('Bu kanal yalnızca izlenebilir.', 'This channel is monitor-only.')
                          : channel.reason,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    finalFanChannelSettings(channel),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget finalFanChannelSettings(FanChannelTelemetry channel) {
    final profile = _profileForFanChannel(channel);
    final cpuValid = isUsableFanTemperature(_cpuTemperature);
    final gpuValid = isUsableFanTemperature(_history.isEmpty ? double.nan : _history.last.gpuTemperature);
    final selectedSensorAvailable = switch (profile.sensorSource) {
      'cpuTemperature' => cpuValid,
      'gpuTemperature' => gpuValid,
      _ => cpuValid || gpuValid,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: profile.sensorSource,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _feedbackText('Sıcaklık kaynağı', 'Temperature source'),
            isDense: true,
          ),
          items: [
            DropdownMenuItem(
              value: 'hottest',
              child: Text(_feedbackText('En sıcak CPU/GPU', 'Hottest CPU/GPU')),
            ),
            DropdownMenuItem(
              value: 'cpuTemperature',
              child: Text(_tr('cpuTemperatureLabel')),
            ),
            DropdownMenuItem(
              value: 'gpuTemperature',
              child: Text(_tr('gpuTemperatureLabel')),
            ),
          ],
          onChanged: (sensor) {
            if (sensor == null) return;
            _updateFanChannelProfile(
              channel.id,
              profile.copyWith(sensorSource: sensor),
            );
          },
        ),
        if (!selectedSensorAvailable) ...[
          const SizedBox(height: 6),
          Text(
            _feedbackText(
              'Seçili sensör verisi yok; bu fanın otomatik eğrisi beklemede.',
              'The selected sensor is unavailable; this fan curve is paused.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(_feedbackText('Otomatik fan eğrisi', 'Automatic fan curve')),
          subtitle: Text(
            _smartFanEnabled
                ? _feedbackText('Ana Smart Fan ayarı açık.', 'The Smart Fan master switch is enabled.')
                : _feedbackText('Önce genel Smart Fan anahtarını açın.', 'Enable the Smart Fan master switch to automate channels.'),
          ),
          value: profile.automaticEnabled,
          onChanged: (enabled) => _updateFanChannelProfile(
            channel.id,
            profile.copyWith(automaticEnabled: enabled),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(_feedbackText('Manuel fan hedefi', 'Manual fan target')),
            ),
            Text('${profile.manualPercent.round()}%'),
          ],
        ),
        Slider(
          value: profile.manualPercent,
          min: 20,
          max: 100,
          divisions: 16,
          label: '${profile.manualPercent.round()}%',
          onChanged: (value) {
            setState(() {
              final current = _profileForFanChannel(channel);
              _fanChannelProfiles[channel.id] =
                  current.copyWith(manualPercent: value);
            });
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isSending
                  ? null
                  : () => _applyFanChannelManualTarget(
                        channel,
                        _profileForFanChannel(channel).manualPercent,
                      ),
              icon: const Icon(Icons.check, size: 16),
              label: Text(_feedbackText('Manuel uygula', 'Apply manually')),
            ),
            OutlinedButton.icon(
              onPressed: () => _openFanChannelCurveEditor(channel),
              icon: const Icon(Icons.show_chart, size: 16),
              label: Text(_feedbackText('Bu fanın eğrisi', 'Edit fan curve')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
    final controllableChannels =
        _fanChannels.where((channel) => channel.supported).length;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_tr('controls'), _tr('safeUserSettings')),
          const SizedBox(height: 6),
          Text(
            _tr('extensionApiStatus'),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(110),
            ),
          ),
          const SizedBox(height: 20),
          if (controllableChannels == 0) ...[
            _buildPresetRow(),
            const SizedBox(height: 14),
            _buildSliderControl(
              _tr('fanSpeed'),
              Icons.air,
              _fanValue.clamp(1, 100).toDouble(),
              (value) => setState(() => _fanValue = value),
              const Color(0xFF64D8CB),
              command: 'Fan Hızı',
            ),
          ] else ...[
            _buildFanChannelsPanel(),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openFanCurveEditor,
                icon: const Icon(Icons.show_chart, size: 16),
                label: Text(_tr('smartFanCurve')),
              ),
              OutlinedButton.icon(
                onPressed: (!_fanControlSupported && controllableChannels == 0)
                    ? null
                    : () {
                        setState(() => _smartFanEnabled = !_smartFanEnabled);
                        unawaited(_saveSettings());
                        _addEvent(_smartFanEnabled
                            ? 'Smart Fan etkinleştirildi'
                            : 'Smart Fan devre dışı bırakıldı');
                      },
                icon: Icon(
                  _smartFanEnabled
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  size: 16,
                ),
                label: Text(
                  _smartFanEnabled
                      ? _tr('smartFanEnabled')
                      : _tr('smartFanDisabled'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openAutomationRules,
                icon: const Icon(Icons.rule, size: 16),
                label: Text(_tr('automation')),
              ),
              OutlinedButton.icon(
                onPressed: _openBenchmark,
                icon: const Icon(Icons.speed, size: 16),
                label: Text(_tr('benchmark')),
              ),
            ],
          ),
          Divider(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
            height: 30,
          ),
          _buildSliderControl(
            _tr('aiProcessingPower'),
            Icons.auto_awesome,
            _aiValue,
            (value) => setState(() => _aiValue = value),
            const Color(0xFF8FA7FF),
            command: 'AI İşlem Gücü',
          ),
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
        if (!_fanControlSupported) Text(_tr('hardwareControlMonitorOnly'), style: const TextStyle(fontSize: 12)),
        _presetButton('quiet', 'Sessiz', Icons.volume_off_outlined, 25, 45, const Color(0xFF64D8CB)),
        _presetButton('balanced', 'Dengeli', Icons.tune, 50, 80, const Color(0xFFFFB454)),
        _presetButton('performance', 'Performans', Icons.speed, 85, 100, const Color(0xFFFF7B7B)),
        _presetButton('game', 'Oyun', Icons.sports_esports_outlined, 75, 95, const Color(0xFFB995FF)),
        _presetButton('manual', 'Manuel', Icons.edit_outlined, _fanValue, _aiValue, const Color(0xFF8FA7FF)),
        TextButton.icon(onPressed: _isSending || !_fanControlSupported ? null : _resetControls, icon: const Icon(Icons.restart_alt, size: 16), label: Text(_tr('reset'))),
        TextButton.icon(onPressed: () => _saveProfile(_tr('manual')), icon: const Icon(Icons.save_outlined, size: 16), label: Text(_tr('saveProfile'))),
      ],
    );
  }

  Widget _presetButton(String labelKey, String legacyProfileName, IconData icon, double fan, double ai, Color color) {
    final label = _tr(labelKey);
    return OutlinedButton.icon(
      onPressed: _isSending || !_fanControlSupported ? null : () => _applyPreset(label, legacyProfileName, fan, ai),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withAlpha(100))),
    );
  }

  Widget _buildSliderControl(String label, IconData icon, double value, ValueChanged<double> onChanged, Color color, {String? command}) {
    // The bridge rejects a zero-percent fan target because it can stop cooling.
    // Keep the manual control within the backend's accepted range instead of
    // letting the user select a value that will always fail at apply time.
    final minimum = command == 'Fan Hızı' ? 1.0 : 0.0;
    final sliderValue = value.clamp(minimum, 100.0).toDouble();
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${sliderValue.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            IconButton(
              tooltip: _tr('apply'),
              onPressed: _isSending || !_fanControlSupported ? null : () => _sendCommand(command ?? label, sliderValue),
              icon: const Icon(Icons.check_circle_outline),
              color: color,
            ),
          ],
        ),
        Slider(
          value: sliderValue,
          min: minimum,
          max: 100,
          divisions: command == 'Fan Hızı' ? 99 : 20,
          activeColor: color,
          onChanged: _fanControlSupported ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildSystemCard() {
    return _Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_tr('systemStatus'), _tr('controlFlow')),
          const SizedBox(height: 20),
          _statusRow('Bridge', _isConnected ? _tr('online') : _tr('offline'), _isConnected),
          _statusRow(_tr('securityLabel'), _sharedKey.isEmpty ? _tr('securityKeyWaiting') : 'HMAC-SHA-256', _sharedKey.isNotEmpty),
          _statusRow(_tr('modelDigestLabel'), _modelDigest == 'unavailable' ? _tr('digestNotFound') : (_modelDigest.length > 12 ? '${_modelDigest.substring(0, 12)}...' : _modelDigest), _modelDigest != 'unavailable' && _modelDigest != 'Kontrol edilmedi'),
          _statusRow('CPU', _cpuCoreCount > 0 ? AppLocalizations.of(context).cpuCoreSummary(_cpuCoreCount, _cpuFrequencyMHz) : _tr('unknown'), _cpuCoreCount > 0),
          _statusRow(_tr('gpuAdapter'), _gpuVendor, _gpuVendor != 'Bilinmiyor'),
          _statusRow(_tr('sensor'), _sensorSource, _sensorSource != 'Kontrol edilmedi'),
          _statusRow(_tr('fanControlLabel'), _fanControlSupported ? _fanControlBackend : _tr('monitoringOnly'), _fanControlSupported),
          _statusRow(_tr('warningThresholdLabel'), '${_temperatureLimit.round()} °C', _notificationsEnabled),
          _statusRow(_tr('temperature'), '${_cpuTemperature.toStringAsFixed(1)} °C', _cpuTemperature < _temperatureLimit || _cpuTemperature == 0),
          _statusRow(_tr('thermalStatusLabel'), _thermalStatus, !_thermalAlertActive),
          _statusRow(_tr('lastActionLabel'), _lastAction, true),
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
              OutlinedButton.icon(onPressed: _isConnected ? null : _connectToBridge, icon: const Icon(Icons.refresh, size: 17), label: Text(_tr('reconnect'))),
              OutlinedButton.icon(onPressed: _updateInfo == null || _updateInfo!.digest.isEmpty || _isCheckingUpdate ? null : _downloadVerifiedUpdate, icon: const Icon(Icons.download_outlined, size: 17), label: Text(_tr('downloadVerifiedUpdate'))),
              OutlinedButton.icon(onPressed: _isConnected ? _exportDiagnosticReport : null, icon: const Icon(Icons.archive_outlined, size: 17), label: Text(_tr('createErrorReport'))),
              OutlinedButton.icon(onPressed: _showFeedbackOptions, icon: const Icon(Icons.feedback_outlined, size: 17), label: Text(_feedbackText('Geri bildirim', 'Feedback'))),
              OutlinedButton.icon(onPressed: _isConnected ? _openHealthCenter : null, icon: const Icon(Icons.health_and_safety_outlined, size: 17), label: Text(_tr('hardwareHealthCenter'))),
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
        _sectionTitle(_tr('systemEvents'), _tr('last20Events')),
        const SizedBox(height: 10),
        if (_events.isEmpty) Text(_tr('noEvents'), style: TextStyle(color: Colors.white54, fontSize: 12)),
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
  const UpdateInfo({required this.tag, required this.releaseUrl, required this.assetName, required this.assetUrl, required this.digest});
  final String tag;
  final String releaseUrl;
  final String assetName;
  final String assetUrl;
  final String digest;
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
