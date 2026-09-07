import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const bool kTestMode = bool.fromEnvironment('HWCONTROL_TEST_MODE');

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key, this.initialize = true});

  final bool initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), useMaterial3: true),
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
  bool _busy = false;
  double _progress = 0;
  String _status = 'Hazır';
  String _details = '';
  Directory? _modelDir;

  @override
  void initState() {
    super.initState();
    if (widget.initialize && !kTestMode) {
      _initialize();
    } else {
      _details = 'Test modu: kurulum ve model indirme atlandı.';
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _status = 'Kurulum hazırlanıyor…';
    });
    try {
      _modelDir = await _modelDirectory();
      await _ensureModel();
      if (mounted) {
        setState(() {
          _status = 'Hazır';
          _details = 'Kurulum bileşenleri doğrulandı.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Hazırlık başarısız';
          _details = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
        '-NoProfile',
        '-NonInteractive',
        '-Command',
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
    final modelPath = Platform.environment['HWCONTROL_MODEL_URL'];
    if (modelPath == null || modelPath.isEmpty) {
      setState(() => _details = 'Model URL ayarlanmadı; yerel kurulum devam ediyor.');
      return;
    }
    final modelDir = _modelDir ?? await _modelDirectory();
    final modelFile = File(p.join(modelDir.path, 'gemma-2b-it-q4_k_m.gguf'));
    if (await modelFile.exists()) return;
    final response = await http.get(Uri.parse(modelPath));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Model indirilemedi: HTTP ${response.statusCode}');
    }
    await modelFile.writeAsBytes(response.bodyBytes);
    if (await modelFile.length() == 0) {
      throw StateError('Model dosyası boş indirildi.');
    }
    await _sha256(modelFile);
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0 && !_busy) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HWControl Installer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: _progress == 0 ? (_step + 1) / 4 : _progress),
            const SizedBox(height: 24),
            Text(_status, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_details),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_step > 0) TextButton(onPressed: _back, child: const Text('Geri')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _next, child: Text(_step == 3 ? 'Bitir' : 'İleri')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const InstallerApp());
}
