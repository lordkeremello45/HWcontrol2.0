import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show HWControlApp;
import 'l10n/app_localizations_map.dart';
import 'services/ai/model_manager.dart';
import 'services/language_service.dart';

void main() => runApp(const InstallerApp());

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key, this.initialize = true});

  final bool initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        final requestedLocale = deviceLocale == null
            ? HWControlLanguageService.systemDefault
            : localeTag(deviceLocale);
        final resolved = HWControlLanguageService.resolveLocale(
          savedLocale: requestedLocale,
          supportedCodes: supportedLocales.map(localeTag),
        );
        return localeFromTag(resolved);
      },
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
  String _details = '';
  String _locale = 'en-US';
  bool _catalogLoaded = false;
  Directory? _stateDirectory;

  String _tr(String key, [Map<String, String> values = const {}]) {
    final l10n = lookupAppLocalizations(localeFromTag(_locale));
    switch (key) {
      case 'installerPackageStepDescription':
        return l10n.installerPackageStepDescription(
          values['platform'] ?? '',
          values['formats'] ?? '',
        );
      case 'installerCheckFailed':
        return l10n.installerCheckFailed(values['error'] ?? '');
      case 'installerModelDownloading':
        return l10n.installerModelDownloading(
          num.tryParse(values['percent'] ?? '') ?? 0,
        );
      case 'installerModelDownloadFailed':
        return l10n.installerModelDownloadFailed(values['error'] ?? '');
      case 'installerPlatformSummary':
        return l10n.installerPlatformSummary(
          values['platform'] ?? '',
          values['formats'] ?? '',
          values['bridge'] ?? '',
          values['ai'] ?? '',
        );
      default:
        return l10n.toStringMap()[key] ?? key;
    }
  }

  Future<void> _loadTranslations() async {
    final locales = AppLocalizations.supportedLocales.map(localeTag).toSet();
    _locale = HWControlLanguageService.resolveLocale(
      savedLocale: HWControlLanguageService.systemDefault,
      supportedCodes: locales,
    );
    _catalogLoaded = true;
  }

  String get _platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }

  String get _packageFormats {
    if (Platform.isWindows) return '.exe/.msi';
    if (Platform.isMacOS) return '.app/.dmg/.pkg';
    if (Platform.isLinux) return '.deb/.rpm/.pkg.tar.zst/archive';
    return 'package';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadTranslations();
    if (!mounted) return;
    setState(() => _details = _tr('installerCheckingComponents'));
    if (widget.initialize) {
      await _inspectInstallation();
    } else {
      setState(() {
        _checking = false;
        _details = _tr('installerTestMode');
      });
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
      // Resolve companion binaries relative to the installed application, not
      // the process working directory (which differs for Desktop shortcuts).
      final executableDirectory = File(Platform.resolvedExecutable).parent;
      final executable = File(
        '${executableDirectory.path}${Platform.pathSeparator}bridge-service',
      );
      final executableWin = File(
        '${executableDirectory.path}${Platform.pathSeparator}bridge-service.exe',
      );
      final bridgePresent = await executable.exists() || await executableWin.exists();
      final completed = await marker.exists();
      if (!mounted) return;
      setState(() {
        _details = completed
            ? _tr('installerPreviouslyCompleted')
            : _tr('installerPlatformSummary', <String, String>{
                'platform': _platformName,
                'formats': _packageFormats,
                'bridge': bridgePresent ? _tr('installerBridgeFound') : _tr('installerBridgePending'),
                'ai': modelReady ? _tr('installerModelReady') : _tr('installerModelOptional'),
              });
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _details = _tr('installerCheckFailed', <String, String>{'error': '$error'});
      });
    }
  }
  Future<void> _complete() async {
    if (_installAiModel) {
      setState(() {
        _aiDownloading = true;
        _aiProgress = 0;
        _details = _tr('installerModelPreparing');
      });
      try {
        await HWControlModelManager.ensureReady(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _aiProgress = progress.clamp(0.0, 1.0);
              _details = _tr('installerModelDownloading', <String, String>{'percent': (_aiProgress * 100).toStringAsFixed(0)});
            });
          },
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _aiDownloading = false;
          _details = _tr('installerModelDownloadFailed', <String, String>{'error': '$error'});
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _aiDownloading = false;
        _aiProgress = 1;
        _details = _tr('installerModelDownloaded');
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
    if (!_catalogLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                    Expanded(child: Text(_tr('installerTitle'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
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
                    title: Text(_tr('installerLocalAiModel')),
                    subtitle: Text(_tr('installerAiDescription')),
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
                          Text(_checking ? _tr('installerCheckingComponents') : _details),
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
                      label: Text(_tr(_step == 2 ? 'installerFinish' : 'installerContinue')),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    _installAiModel
                        ? _tr('installerAiSelectedFooter')
                        : _tr('installerAiSkippedFooter'),
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
      case 0: return _tr('installerPackageStepTitle');
      case 1: return _tr('installerBridgeStepTitle');
      default: return _tr('installerCompleteStepTitle');
    }
  }

  String _bodyForStep() {
    switch (_step) {
      case 0: return _tr('installerPackageStepDescription', <String, String>{'platform': _platformName, 'formats': _packageFormats});
      case 1: return _tr('installerAiStepDescription');
      default: return _installAiModel ? _tr('installerCompleteWithAi') : _tr('installerCompleteWithoutAi');
    }
  }
}
