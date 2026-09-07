import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show HWControlApp;

void main() => runApp(const InstallerApp());

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key, this.initialize = true});

  final bool initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: InstallerWizard(initialize: initialize),
    );
  }
}

class InstallerWizard extends StatefulWidget {
  const InstallerWizard({super.key, this.initialize = true});

  final bool initialize;

  @override
  State<InstallerWizard> createState() => _InstallerWizardState();
}

class _InstallerWizardState extends State<InstallerWizard> {
  static const _modelName = 'gemma-2b-it-q4_k_m.gguf';
  static const _modelUrl = 'https://huggingface.co/second-state/Gemma-2b-it-GGUF/resolve/main/gemma-2b-it-Q4_K_M.gguf?download=true';
  static const _modelSha256 = '4d736aa91fa06bb4d72a9e9017ad4e5c6a8fc16fb01b748c9b8332293c855402';
  static const _modelSize = 1495095008;

  int _step = 0;
  bool _checking = true;
  bool _modelReady = false;
  bool _modelDownloading = false;
  String? _modelError;
  String _details = 'Kurulum bileşenleri kontrol ediliyor...';
  Directory? _stateDirectory;
  File? _modelFile;

  String get _platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }

  String get _packageFormats {
    if (Platform.isWindows) return '.exe veya .msi';
    if (Platform.isMacOS) return '.app, .dmg veya .pkg';
    if (Platform.isLinux) return '.deb, .rpm, .pkg.tar.zst veya archive';
    return 'platform paketi';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialize) {
      _inspectInstallation();
    } else {
      _checking = false;
      _details = 'Test modu: kurulum ve model indirme atlandı.';
    }
  }

  Future<Directory> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}models');
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> _sha256(File file) async {
    ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        '(Get-FileHash -Algorithm SHA256 -LiteralPath \$args[0]).Hash.ToLowerInvariant()',
        file.path,
      ]);
    } else if (Platform.isMacOS) {
      result = await Process.run('shasum', ['-a', '256', file.path]);
    } else {
      result = await Process.run('sha256sum', [file.path]);
    }
    if (result.exitCode != 0) throw StateError('SHA-256 hesaplanamadı: ${result.stderr}');
    final match = RegExp(r'[0-9a-fA-F]{64}').firstMatch(result.stdout.toString());
    if (match == null) throw StateError('SHA-256 çıktısı geçersiz.');
    return match.group(0)!.toLowerCase();
  }

  Future<void> _ensureModel() async {
    final directory = await _modelDirectory();
    final target = File('${directory.path}${Platform.pathSeparator}$_modelName');
    _modelFile = target;
    _modelError = null;

    if (await target.exists()) {
      final length = await target.length();
      if (length == _modelSize && await _sha256(target) == _modelSha256) {
        _modelReady = true;
        return;
      }
      await target.delete();
    }

    if (!mounted) return;
    setState(() => _modelDownloading = true);
    final partial = File('${target.path}.part');
    try {
      if (await partial.exists()) await partial.delete();
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      try {
        final request = await client.getUrl(Uri.parse(_modelUrl));
        request.followRedirects = true;
        request.maxRedirects = 5;
        request.headers.set(HttpHeaders.userAgentHeader, 'HWControl/0.2 model-installer');
        final response = await request.close().timeout(const Duration(minutes: 2));
        if (response.statusCode != HttpStatus.ok) {
          throw StateError('Model sunucusu HTTP ${response.statusCode} döndürdü.');
        }
        final sink = partial.openWrite();
        await response.pipe(sink);
      } finally {
        client.close(force: true);
      }

      final length = await partial.length();
      if (length != _modelSize) {
        throw StateError('Model boyutu doğrulanamadı: $length / $_modelSize byte.');
      }
      final digest = await _sha256(partial);
      if (digest != _modelSha256) {
        throw StateError('Model SHA-256 doğrulaması başarısız. Beklenen: $_modelSha256, alınan: $digest');
      }
      await partial.rename(target.path);
      _modelReady = true;
    } catch (error) {
      _modelReady = false;
      _modelError = 'Gemma modeli indirilemedi veya doğrulanamadı.\n$error';
      if (await partial.exists()) await partial.delete();
    } finally {
      if (mounted) setState(() => _modelDownloading = false);
    }
  }

  Future<void> _inspectInstallation() async {
    try {
      final support = await getApplicationSupportDirectory();
      _stateDirectory = Directory('${support.path}${Platform.pathSeparator}HWControl');
      await _ensureModel();
      final marker = File('${_stateDirectory!.path}${Platform.pathSeparator}setup.complete');
      final executable = File('${Directory.current.path}${Platform.pathSeparator}bridge-service');
      final executableWin = File('${Directory.current.path}${Platform.pathSeparator}bridge-service.exe');
      final bridgePresent = await executable.exists() || await executableWin.exists();
      final completed = await marker.exists();
      if (!mounted) return;
      setState(() {
        _details = completed
            ? 'Kurulum daha önce tamamlandı. Model cache ve bileşenler yeniden doğrulandı.'
            : 'Platform: $_platformName\nPaket: $_packageFormats\nBridge: ${bridgePresent ? 'bulundu' : 'paketlenmiş kurulumdan bekleniyor'}\nModel: ${_modelReady ? 'SHA-256 doğrulandı' : 'hazır değil'}\nCache: ${_modelFile?.path ?? 'oluşturulamadı'}';
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _modelReady = false;
        _modelError = 'Model kurulumu başlatılamadı.\n$error';
        _details = 'Kurulum denetimi tamamlanamadı: $error';
      });
    }
  }

  Future<void> _retryModel() async {
    if (_modelDownloading) return;
    setState(() {
      _checking = true;
      _modelError = null;
    });
    await _inspectInstallation();
  }

  Future<void> _complete() async {
    if (!_modelReady) return;
    try {
      final directory = _stateDirectory ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      await File('${directory.path}${Platform.pathSeparator}setup.complete').writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HWControlApp()));
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    _complete();
  }

  @override
  Widget build(BuildContext context) {
    final error = _modelError;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.install_desktop, size: 34),
                    const SizedBox(width: 14),
                    Expanded(child: Text('HWControl Kurulum Sihirbazı', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                    Text(_platformName, style: Theme.of(context).textTheme.labelLarge),
                  ]),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(value: (_step + 1) / 3),
                  const SizedBox(height: 24),
                  Text(_titleForStep(), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(_bodyForStep()),
                  const SizedBox(height: 18),
                  if (_step == 2) ...[
                    if (_modelDownloading) const LinearProgressIndicator(),
                    if (_modelDownloading) const SizedBox(height: 12),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.errorContainer,
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 8), const Expanded(child: Text('Model kurulumu başarısız'))]),
                          const SizedBox(height: 8),
                          SelectableText(error),
                          const SizedBox(height: 12),
                          FilledButton.icon(onPressed: _modelDownloading ? null : _retryModel, icon: const Icon(Icons.refresh), label: const Text('Tekrar dene')),
                        ]),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainerHighest),
                        child: _checking ? const LinearProgressIndicator() : SelectableText(_details),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _checking && _step == 2 || (_step == 2 && !_modelReady) ? null : _next,
                      icon: Icon(_step == 2 ? Icons.rocket_launch : Icons.arrow_forward),
                      label: Text(_step == 2 ? 'Kurulumu tamamla' : 'Devam'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text('Model ilk çalıştırmada indirilir, SHA-256 ile doğrulanır ve kullanıcı uygulama cache dizininde saklanır.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case 0: return '1. Paket türünü doğrula';
      case 1: return '2. Bridge ve modeli hazırla';
      default: return '3. Modeli doğrula ve kurulumu tamamla';
    }
  }

  String _bodyForStep() {
    switch (_step) {
      case 0: return 'Bu çalıştırmada $_platformName için uygun paket biçimi $_packageFormats.';
      case 1: return 'Gemma 2B Instruct Q4_K_M modeli ilk çalıştırmada otomatik olarak indirilir. Eksik veya bozuk cache dosyası yeniden indirilir.';
      default: return 'Model bulunamazsa veya SHA-256 eşleşmezse uygulama başlamaz; ekranda nedeni ve yeniden deneme seçeneği gösterilir.';
    }
  }
}
