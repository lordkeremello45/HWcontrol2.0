import 'package:flutter/material.dart';

/// First-run welcome screen based on the approved HWcontrol2.0 Canva design.
///
/// Implemented as native Flutter UI so it stays responsive and consistent
/// across Windows, Linux, and macOS.
class HWControlWelcomeScreen extends StatefulWidget {
  const HWControlWelcomeScreen({
    super.key,
    required this.onContinue,
    required this.onSettings,
  });

  final ValueChanged<bool> onContinue;
  final VoidCallback onSettings;

  @override
  State<HWControlWelcomeScreen> createState() => _HWControlWelcomeScreenState();
}

class _HWControlWelcomeScreenState extends State<HWControlWelcomeScreen> {
  bool _dontShowAgain = true;

  static const _ink = Color(0xFF17202A);
  static const _panel = Color(0xFF1E2933);
  static const _primary = Color(0xFF176B63);
  static const _primaryDark = Color(0xFF0E4F4A);
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
        const Text(
          'Welcome to HWcontrol2.0',
          style: TextStyle(
            color: _mint,
            fontSize: 42,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Monitor. Control. Protect.',
          style: TextStyle(
            color: Color(0xFF64D8CB),
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          width: 520,
          child: Text(
            'A simple, reliable way to monitor your hardware, control cooling, and keep your system healthy.',
            style: TextStyle(
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
          children: const [
            _FeaturePill(
              icon: Icons.monitor_heart_outlined,
              title: 'Monitor',
              description: 'CPU/GPU sensors and temperatures',
            ),
            _FeaturePill(
              icon: Icons.tune_rounded,
              title: 'Control',
              description: 'Fan curves and performance profiles',
            ),
            _FeaturePill(
              icon: Icons.shield_outlined,
              title: 'Protect',
              description: 'Diagnostics and system status',
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
              child: const Text(
                'Get Started',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: widget.onSettings,
              style: TextButton.styleFrom(
                foregroundColor: _mint,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              ),
              child: const Text('Settings'),
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
                const Text(
                  "Don't show this again",
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF10171E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary, width: 2),
      ),
      child: Center(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _primaryDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'H',
              style: TextStyle(
                color: _mint,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
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
            children: const [
              Icon(Icons.space_dashboard_outlined, color: _muted, size: 18),
              SizedBox(width: 8),
              Text(
                'System status',
                style: TextStyle(
                  color: _mint,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              _StatusDot(),
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
          const _StatusRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'System OK',
          ),
          const _StatusRow(
            icon: Icons.system_update_alt_rounded,
            text: 'Up to date',
          ),
          const _StatusRow(
            icon: Icons.verified_outlined,
            text: 'No Issues',
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
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFEEF7F5),
              fontSize: 13,
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
