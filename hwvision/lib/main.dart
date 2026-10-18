import 'package:flutter/material.dart';

import 'display_capabilities.dart';

void main() {
  runApp(const HwVisionApp());
}

class HwVisionApp extends StatelessWidget {
  const HwVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HWVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF67E8F9),
          brightness: Brightness.dark,
          surface: const Color(0xFF111827),
        ),
        scaffoldBackgroundColor: const Color(0xFF080D17),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF273449)),
          ),
        ),
      ),
      home: const DisplayDashboard(),
    );
  }
}

class DisplayDashboard extends StatefulWidget {
  const DisplayDashboard({super.key});

  @override
  State<DisplayDashboard> createState() => _DisplayDashboardState();
}

class _DisplayDashboardState extends State<DisplayDashboard> {
  String _profile = 'Dengeli';

  // This remains explicitly unknown until a native adapter queries the OS.
  late final DisplayCapabilities _capabilities =
      DisplayCapabilities.unavailable(platform: _platformName);

  String get _platformName {
    // dart:io is intentionally not imported so this UI remains web-compilable.
    // Native adapters will provide the real platform identifier.
    return 'Algılanmayı bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              backgroundColor: const Color(0xFF0B1220),
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: Text('Ekran'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.palette_outlined),
                  label: Text('Renk'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune),
                  label: Text('Profiller'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: Color(0xFF273449)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Header(),
                        const SizedBox(height: 24),
                        _Notice(
                          title: 'İlk prototip',
                          message:
                              'Ekran özellikleri henüz işletim sisteminden okunmuyor. '
                              'HDR, renk profili ve Dolby Vision durumu doğrulanana '
                              'kadar bilinmiyor olarak gösterilir; hiçbir sistem '
                              'ayarınız değiştirilmez.',
                        ),
                        const SizedBox(height: 24),
                        _SectionTitle(
                          title: 'Ekran durumu',
                          subtitle: 'Yerel platform algılayıcısı bağlanmayı bekliyor',
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF164E63),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.desktop_windows_outlined,
                                    size: 34,
                                    color: Color(0xFF67E8F9),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _capabilities.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Platform: ${_capabilities.platform}',
                                        style: const TextStyle(
                                          color: Color(0xFF9CAFC4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const _StatePill(
                                  label: 'Algılanmadı',
                                  color: Color(0xFFFBBF24),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle(
                          title: 'Görüntü yetenekleri',
                          subtitle: 'Yalnızca yerel API ile doğrulanan özellikler etkinleşir',
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 4 : 2;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.25,
                              children: const [
                                _CapabilityCard(
                                  icon: Icons.hdr_auto,
                                  title: 'HDR',
                                  subtitle: 'İşletim sistemi desteği',
                                  state: CapabilityState.unknown,
                                ),
                                _CapabilityCard(
                                  icon: Icons.color_lens_outlined,
                                  title: 'Geniş renk gamı',
                                  subtitle: 'Renk alanı',
                                  state: CapabilityState.unknown,
                                ),
                                _CapabilityCard(
                                  icon: Icons.speed,
                                  title: 'Değişken yenileme',
                                  subtitle: 'VRR / ekran sürücüsü',
                                  state: CapabilityState.unknown,
                                ),
                                _CapabilityCard(
                                  icon: Icons.movie_filter_outlined,
                                  title: 'Dolby Vision',
                                  subtitle: 'Lisans ve donanım gerekir',
                                  state: CapabilityState.unknown,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle(
                          title: 'Görüntü profili önizlemesi',
                          subtitle:
                              'Şimdilik yalnızca uygulama içi seçimdir; ekran ayarlarını değiştirmez',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ProfileButton(
                              label: 'Doğal',
                              icon: Icons.spa_outlined,
                              selected: _profile == 'Doğal',
                              onTap: () => setState(() => _profile = 'Doğal'),
                            ),
                            _ProfileButton(
                              label: 'Film',
                              icon: Icons.local_movies_outlined,
                              selected: _profile == 'Film',
                              onTap: () => setState(() => _profile = 'Film'),
                            ),
                            _ProfileButton(
                              label: 'Oyun',
                              icon: Icons.sports_esports_outlined,
                              selected: _profile == 'Oyun',
                              onTap: () => setState(() => _profile = 'Oyun'),
                            ),
                            _ProfileButton(
                              label: 'Dengeli',
                              icon: Icons.balance_outlined,
                              selected: _profile == 'Dengeli',
                              onTap: () =>
                                  setState(() => _profile = 'Dengeli'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Seçili önizleme: $_profile',
                          style: const TextStyle(color: Color(0xFF9CAFC4)),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'HWVision • 0.1.0 prototype • HWcontrol ekosistemi',
                          style: TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [Color(0xFF0891B2), Color(0xFF6366F1)],
              ),
            ),
            child: const Icon(Icons.visibility_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HWVision',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                ),
                const Text(
                  'Ekran ve görüntü deneyimi yönetimi',
                  style: TextStyle(color: Color(0xFF9CAFC4)),
                ),
              ],
            ),
          ),
          const _StatePill(
            label: 'PROTOTİP',
            color: Color(0xFF67E8F9),
          ),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8192A8), fontSize: 13),
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF302719),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF795B25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFBBF24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 5),
                  Text(message,
                      style: const TextStyle(
                        color: Color(0xFFE7DCC7),
                        height: 1.45,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final CapabilityState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      CapabilityState.supported => ('Destekleniyor', const Color(0xFF34D399)),
      CapabilityState.unsupported => ('Desteklenmiyor', const Color(0xFFF87171)),
      CapabilityState.unknown => ('Bilinmiyor', const Color(0xFFFBBF24)),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF67E8F9), size: 25),
            const Spacer(),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8192A8), fontSize: 11),
            ),
            const SizedBox(height: 8),
            _StatePill(label: label, color: color),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              selected ? const Color(0xFF67E8F9) : const Color(0xFFB7C4D6),
          side: BorderSide(
            color: selected
                ? const Color(0xFF67E8F9)
                : const Color(0xFF34445B),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      );
}
