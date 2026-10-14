import 'package:flutter/material.dart';

/// Guided first-run setup. This wizard only records user choices; it never
/// changes fan hardware settings or assumes that a backend is available.
class HWControlSetupWizard extends StatefulWidget {
  const HWControlSetupWizard({
    super.key,
    required this.onComplete,
    required this.onCancel,
    this.translations = const <String, String>{},
    this.initialProfile = 'balanced',
    this.initialStartWithSystem = false,
  });

  final ValueChanged<Map<String, dynamic>> onComplete;
  final VoidCallback onCancel;
  final Map<String, String> translations;
  final String initialProfile;
  final bool initialStartWithSystem;

  @override
  State<HWControlSetupWizard> createState() => _HWControlSetupWizardState();
}

class _HWControlSetupWizardState extends State<HWControlSetupWizard> {
  int _step = 0;
  late String _profile = widget.initialProfile;
  late bool _startWithSystem = widget.initialStartWithSystem;
  bool _enableAutomaticFan = false;
  bool _acknowledgedSafety = false;

  static const int _lastStep = 3;

  String _t(String key, String fallback) {
    final value = widget.translations[key];
    return value == null || value.trim().isEmpty ? fallback : value;
  }

  void _next() {
    if (_step == 2 && !_acknowledgedSafety) return;
    if (_step < _lastStep) {
      setState(() => _step++);
      return;
    }
    widget.onComplete(<String, dynamic>{
      'setupWizardCompleted': true,
      'preferredProfile': _profile,
      'startWithSystem': _startWithSystem,
      'automaticFanControlRequested': _enableAutomaticFan,
      'fanSafetyAcknowledged': _acknowledgedSafety,
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = <String>[
      _t('wizardProfileTitle', 'Choose a starting profile'),
      _t('wizardStartupTitle', 'Startup preferences'),
      _t('wizardSafetyTitle', 'Hardware-control safety'),
      _t('wizardReadyTitle', 'Review and finish'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.tune, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('wizardTitle', 'HWcontrol2.0 Setup'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text('${_step + 1}/${_lastStep + 1}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: (_step + 1) / (_lastStep + 1)),
                  const SizedBox(height: 24),
                  Text(titles[_step], style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStep(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: widget.onCancel,
                        child: Text(_t('wizardCancel', 'Cancel setup')),
                      ),
                      const Spacer(),
                      if (_step > 0)
                        OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          child: Text(_t('wizardBack', 'Back')),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _step == 2 && !_acknowledgedSafety ? null : _next,
                        child: Text(
                          _step == _lastStep
                              ? _t('wizardFinish', 'Finish')
                              : _t('wizardNext', 'Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(_t(
              'wizardProfileDescription',
              'Choose a starting preference. This does not overclock your hardware or guarantee a performance increase.',
            )),
            const SizedBox(height: 16),
            for (final option in <(String, String, String)>[
              ('quiet', 'Quiet', 'Prioritise lower fan noise where supported.'),
              ('balanced', 'Balanced', 'Use a general-purpose starting preference.'),
              ('performance', 'Performance', 'Prefer cooling response; this is not an overclock.'),
            ])
              Card(
                child: RadioListTile<String>(
                  value: option.$1,
                  groupValue: _profile,
                  onChanged: (value) {
                    if (value != null) setState(() => _profile = value);
                  },
                  title: Text(_t('wizardProfile_${option.$1}', option.$2)),
                  subtitle: Text(_t('wizardProfileDescription_${option.$1}', option.$3)),
                ),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _startWithSystem,
              onChanged: (value) => setState(() => _startWithSystem = value),
              title: Text(_t('wizardStartWithSystem', 'Start HWcontrol with the system')),
              subtitle: Text(_t(
                'wizardStartupDescription',
                'This records your preference only. Startup integration is applied only if the current platform supports it.',
              )),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enableAutomaticFan,
              onChanged: (value) => setState(() => _enableAutomaticFan = value),
              title: Text(_t('wizardRequestAutoFan', 'Request automatic fan curves')),
              subtitle: Text(_t(
                'wizardAutoFanDescription',
                'The request is saved for setup review. Actual fan control requires a supported, validated hardware backend.',
              )),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.shield_outlined, size: 56),
            const SizedBox(height: 12),
            Text(_t(
              'wizardSafetyDescription',
              'Hardware support differs by device and operating system. A visible control does not mean the hardware supports writing to it. Do not disable firmware safety controls. If telemetry is missing or invalid, automatic control must remain inactive.',
            )),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acknowledgedSafety,
              onChanged: (value) => setState(() => _acknowledgedSafety = value ?? false),
              title: Text(_t(
                'wizardSafetyAcknowledge',
                'I understand that hardware control is enabled only when the backend confirms support.',
              )),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 56),
            const SizedBox(height: 12),
            Text(_t(
              'wizardSummaryDescription',
              'Your choices are ready to save. HWcontrol will not apply unsupported hardware settings.',
            )),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(_t('wizardSummaryProfile', 'Starting profile')),
              subtitle: Text(_t('wizardProfile_$_profile', _profile)),
            ),
            ListTile(
              leading: const Icon(Icons.power_settings_new),
              title: Text(_t('wizardSummaryStartup', 'Start with system')),
              subtitle: Text(_startWithSystem
                  ? _t('enabled', 'Enabled')
                  : _t('disabled', 'Disabled')),
            ),
            ListTile(
              leading: const Icon(Icons.air),
              title: Text(_t('wizardSummaryFan', 'Automatic fan curves')),
              subtitle: Text(_enableAutomaticFan
                  ? _t('wizardRequested', 'Requested; hardware support will be checked')
                  : _t('wizardNotRequested', 'Not requested')),
            ),
          ],
        );
    }
  }
}
