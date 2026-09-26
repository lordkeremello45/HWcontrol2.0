import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show HWControlApp;
import 'model_manager.dart';

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
  int _step = 0;
  bool _checking = true;
  bool _installAiModel = true;
  bool _aiDownloading = false;
  double _aiProgress = 0;
  String _details = 'Kurulum bileşenleri kontrol ediliyor...';
  Directory? _stateDirectory;

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

  Future<void> _inspectInstallation() async {
    try {
      final support = await getApplicationSupportDirectory();
      _stateDirectory = Directory(
        '${support.path}${Platform.pathSeparator}HWControl',
      );
      final modelReady = await HWControlModelManager.isReady();
      final marker = File(
        '${_stateDirectory!.path}${Platform.pathSeparator}setup.complete',
      );
      final executable = File(
        '${Directory.current.path}${Platform.pathSeparator}bridge-service',
      );
      final executableWin = File(
        '${Directory.current.path}${Platform.pathSeparator}bridge-service.exe',
      );
      final bridgePresent = await executable.exists() || await executableWin.exists();
      final completed = await marker.exists();
      if (!mounted) return;
      setState(() {
        _details = completed
            ? 'Kurulum daha önce tamamlandı. AI modeli isteğe bağlıdır.'
            : 'Platform: $_platformName\n'
                'Paket: $_packageFormats\n'
                'Bridge: ${bridgePresent ? 'bulundu' : 'paketlenmiş kurulumdan bekleniyor'}\n'
                'AI modeli: ${modelReady ? 'hazır ve doğrulanmış' : 'isteğe bağlı; ilk AI analizinde indirilir'}';
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _details = 'Kurulum denetimi tamamlanamadı: $error';
      });
    }
  }
  Future<void> _complete() async {
    if (_installAiModel) {
      setState(() {
        _aiDownloading = true;
        _aiProgress = 0;
        _details = 'Gemma 3 1B modeli hazırlanıyor...';
      });
      try {
        await HWControlModelManager.ensureReady(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _aiProgress = progress.clamp(0.0, 1.0);
              _details = 'Gemma 3 1B indiriliyor: ${(_aiProgress * 100).toStringAsFixed(0)}%';
            });
          },
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _aiDownloading = false;
          _details = 'Gemma kurulamadı: $error\nTemel kurulum devam edebilir; AI daha sonra tekrar denenebilir.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _aiDownloading = false;
        _aiProgress = 1;
        _details = 'Gemma 3 1B indirildi ve SHA-256 ile doğrulandı.';
      });
    }
    try {
      final directory = _stateDirectory ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      await File(
        '${directory.path}${Platform.pathSeparator}setup.complete',
      ).writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HWControlApp()),
    );
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
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _installAiModel,
                    onChanged: _aiDownloading
                        ? null
                        : (value) => setState(() => _installAiModel = value ?? false),
                    title: const Text('Yerel AI (Gemma 3 1B)'),
                    subtitle: const Text(
                      'İsteğe bağlı. Seçilirse Gemma 3 1B modeli kurulum sırasında indirilir ve SHA-256 ile doğrulanır.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 18),
                  if (_step == 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_checking ? 'Kurulum kontrol ediliyor...' : _details),
                          if (_aiDownloading) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(value: _aiProgress),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: (_checking && _step == 2) || _aiDownloading ? null : _next,
                      icon: Icon(_step == 2 ? Icons.rocket_launch : Icons.arrow_forward),
                      label: Text(_step == 2 ? 'Kurulumu tamamla' : 'Devam'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    _installAiModel
                        ? 'AI seçildi: Gemma kurulum sırasında hazırlanır. Eksik veya bozuk model tespit edilirse yeniden indirilerek otomatik onarılır.'
                        : 'AI seçilmedi: Gemma kurulmaz. İlk AI analizi istendiğinde model güvenli biçimde indirilebilir.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
      case 1: return '2. Bridge durumunu doğrula';
      default: return '3. Kurulumu tamamla';
    }
  }

  String _bodyForStep() {
    switch (_step) {
      case 0: return 'Bu çalıştırmada $_platformName için uygun paket biçimi $_packageFormats.';
      case 1: return 'Yerel AI bileşenini isteğe bağlı olarak kur. Seçersen Gemma 3 1B Instruct Q5_K_M (~851 MB) kurulum sırasında indirilir ve SHA-256 ile doğrulanır.';
      default: return _installAiModel ? 'Kurulum son adımında model hazırlanır. Eksik veya bozuk bir model varsa güvenli indirme ile otomatik onarılır.' : 'Temel uygulama kurulumu tamamlanır; AI modeli bu kurulumda indirilmez.';
    }
  }
}
