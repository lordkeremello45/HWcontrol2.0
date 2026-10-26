import 'package:flutter/material.dart';

import 'pulsar_mark.dart';

/// First-run welcome screen based on the approved HWcontrol2.0 Canva design.
///
/// Implemented as native Flutter UI so it stays responsive and consistent
/// across Windows, Linux, and macOS.
class HWControlWelcomeScreen extends StatefulWidget {
  const HWControlWelcomeScreen({
    super.key,
    required this.onContinue,
    required this.onSettings,
    this.translations = const <String, String>{},
  });

  final ValueChanged<bool> onContinue;
  final VoidCallback onSettings;
  final Map<String, String> translations;

  @override
  State<HWControlWelcomeScreen> createState() => _HWControlWelcomeScreenState();
}

class _HWControlWelcomeScreenState extends State<HWControlWelcomeScreen> {
  bool _dontShowAgain = false;

  String _text(String key, String fallback) =>
      widget.translations[key]?.trim().isNotEmpty == true
          ? widget.translations[key]!.trim()
          : fallback;

  static const _ink = Color(0xFF17202A);
  static const _panel = Color(0xFF1E2933);
  static const _primary = Color(0xFF176B63);
  static const _mint = Color(0xFFEEF7F5);
  static const _muted = Color(0xFF9BA6B0);
  static const _line = Color(0xFF33404B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 24 : 56,
                  vertical: compact ? 28 : 44,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: compact
                      ? _buildCompactLayout(context)
                      : _buildDesktopLayout(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: _buildIntro(context)),
        const SizedBox(width: 64),
        Expanded(flex: 10, child: _buildSystemPreview()),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntro(context),
        const SizedBox(height: 36),
        _buildSystemPreview(),
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogo(),
        const SizedBox(height: 34),
        Text(
          _text('welcomeTitle', 'Welcome to HWcontrol2.0'),
          style: const TextStyle(
            color: _mint,
            fontSize: 42,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _text('welcomeTagline', 'Monitor. Control. Protect.'),
          style: const TextStyle(
            color: Color(0xFF64D8CB),
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Text(
            _text('welcomeDescription', 'A simple, reliable way to monitor your hardware, control cooling, and keep your system healthy.'),
            style: const TextStyle(
              color: _muted,
              fontSize: 16,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FeaturePill(
              icon: Icons.monitor_heart_outlined,
              title: _text('welcomeMonitor', 'Monitor'),
              description: _text('welcomeMonitorDescription', 'CPU/GPU sensors and temperatures'),
            ),
            _FeaturePill(
              icon: Icons.tune_rounded,
              title: _text('welcomeControl', 'Control'),
              description: _text('welcomeControlDescription', 'Fan curves and performance profiles'),
            ),
            _FeaturePill(
              icon: Icons.shield_outlined,
              title: _text('welcomeProtect', 'Protect'),
              description: _text('welcomeProtectDescription', 'Diagnostics and system status'),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Row(
          children: [
            FilledButton(
              onPressed: () => widget.onContinue(_dontShowAgain),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _text('welcomeGetStarted', 'Get Started'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: widget.onSettings,
              style: TextButton.styleFrom(
                foregroundColor: _mint,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              ),
              child: Text(_text('welcomeOpenDashboard', 'Open Dashboard')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  onChanged: (value) =>
                      setState(() => _dontShowAgain = value ?? false),
                  activeColor: _primary,
                  checkColor: Colors.white,
                  side: const BorderSide(color: _muted),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
                Text(
                  _text('welcomeDontShowAgain', "Don't show this again"),
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return const PulsarMark(size: 96, animate: true);
  }

  Widget _buildSystemPreview() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.space_dashboard_outlined, color: _muted, size: 18),
              const SizedBox(width: 8),
              Text(
                _text('welcomePreview', 'Dashboard preview'),
                style: const TextStyle(
                  color: _mint,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const _StatusDot(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  label: 'CPU',
                  value: '62°C',
                  icon: Icons.memory_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'GPU',
                  value: '56°C',
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.check_circle_outline_rounded,
            text: _text('welcomeExampleStatus', 'Example status only'),
          ),
          _StatusRow(
            icon: Icons.system_update_alt_rounded,
            text: _text('welcomeSampleValues', 'Sample values — not live data'),
          ),
          _StatusRow(
            icon: Icons.verified_outlined,
            text: _text('welcomeConnectHardware', 'Connect to view your hardware'),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x12176763),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2633404B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF64D8CB), size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFEEF7F5),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF9BA6B0),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17202A),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF33404B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF64D8CB), size: 18),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9BA6B0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFEEF7F5),
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64D8CB), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEEF7F5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: Color(0xFF64D8CB),
        shape: BoxShape.circle,
      ),
    );
  }
}
