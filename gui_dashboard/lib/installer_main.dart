import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show HWControlApp;

void main() => runApp(const InstallerApp());

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const InstallerWizard(),
    );
  }
}

class InstallerWizard extends StatefulWidget {
  const InstallerWizard({super.key});

  @override
  State<InstallerWizard> createState() => _InstallerWizardState();
}

class _InstallerWizardState extends State<InstallerWizard> {
  int _step = 0;
  bool _checking = true;
  bool _ready = false;
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
    if (Platform.isLinux) return '.deb veya Arch için .pkg.tar.zst';
    return 'platform paketi';
  }

  @override
  void initState() {
    super.initState();
    _inspectInstallation();
  }

  Future<void> _inspectInstallation() async {
    try {
      final support = await getApplicationSupportDirectory();
      _stateDirectory = Directory('${support.path}${Platform.pathSeparator}HWControl');
      final marker = File('${_stateDirectory!.path}${Platform.pathSeparator}setup.complete');
      final executable = File('${Directory.current.path}${Platform.pathSeparator}bridge-service');
      final executableWin = File('${Directory.current.path}${Platform.pathSeparator}bridge-service.exe');
      final model = File('${Directory.current.path}${Platform.pathSeparator}gemma-2b-it-q4_k_m.gguf');
      final bridgePresent = await executable.exists() || await executableWin.exists();
      final modelPresent = await model.exists();
      final completed = await marker.exists();
      if (!mounted) return;
      setState(() {
        _ready = bridgePresent && (Platform.environment['HWCONTROL_KEY']?.isNotEmpty ?? false);
        _details = completed
            ? 'Kurulum daha önce tamamlandı. Yapılandırmayı yeniden doğrulayabilirsiniz.'
            : 'Platform: $_platformName\nPaket: $_packageFormats\nBridge: ${bridgePresent ? 'bulundu' : 'paketlenmiş kurulumdan bekleniyor'}\nModel: ${modelPresent ? 'bulundu' : 'harici olarak eklenmeli'}\nHWCONTROL_KEY: ${Platform.environment['HWCONTROL_KEY']?.isNotEmpty == true ? 'ayarlı' : 'ayarlı değil'}';
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _ready = false;
        _details = 'Kurulum denetimi tamamlanamadı: $error';
      });
    }
  }

  Future<void> _complete() async {
    try {
      final directory = _stateDirectory ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      await File('${directory.path}${Platform.pathSeparator}setup.complete').writeAsString(DateTime.now().toUtc().toIso8601String());
    } catch (_) {
      // Completing the wizard must not prevent the dashboard from starting.
    }
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
                  Row(
                    children: [
                      const Icon(Icons.install_desktop, size: 34),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('HWControl Kurulum Sihirbazı', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text(_platformName, style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(value: (_step + 1) / 3),
                  const SizedBox(height: 24),
                  Text(_titleForStep(), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(_bodyForStep()),
                  const SizedBox(height: 18),
                  if (_step == 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: _checking ? const LinearProgressIndicator() : SelectableText(_details),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_step == 2)
                        TextButton(onPressed: _complete, child: const Text('Atla')),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _checking && _step == 2 ? null : _next,
                        icon: Icon(_step == 2 ? Icons.rocket_launch : Icons.arrow_forward),
                        label: Text(_step == 2 ? 'Kurulumu tamamla' : 'Devam'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Not: Paket yükleme işletim sistemi tarafından yapılır; bu sihirbaz ilk çalıştırma ve bileşen doğrulamasını yönetir.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!_ready && _step == 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Donanım kontrol komutları kullanılmadan önce bridge ve HWCONTROL_KEY yapılandırılmalıdır.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
      case 0:
        return '1. Paket türünü doğrula';
      case 1:
        return '2. Bridge ve modeli hazırla';
      default:
        return '3. Kurulumu doğrula';
    }
  }

  String _bodyForStep() {
    switch (_step) {
      case 0:
        return 'Bu çalıştırmada $_platformName için uygun paket biçimi $_packageFormats. Windows için .exe/.msi, macOS için .app/.dmg/.pkg, Linux için .deb veya .pkg.tar.zst kullanılır.';
      case 1:
        return 'Bridge servisi, AI modeli ve HWCONTROL_KEY çalışma zamanı bileşenleridir. Kurulum paketi bunları doğru konuma yerleştirmeli; model pakete dahil değilse ayrı ve doğrulanmış bir dosya olarak eklenmelidir.';
      default:
        return 'Kurulumdan sonra dosyaları ve ortam değişkenlerini kontrol edin. Gerçek fan/GPU kontrolü yalnızca desteklenen fiziksel donanım ve uygun ayrıcalıklar üzerinde etkinleştirilmelidir.';
    }
  }
}
