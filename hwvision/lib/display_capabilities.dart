/// Display capability model shared by platform-specific adapters and UI.
///
/// Unknown is intentionally distinct from unsupported: an unimplemented or
/// failed native adapter must never make the UI claim a capability exists.
enum CapabilityState { supported, unsupported, unknown }

enum DisplayFeature { hdr, wideColorGamut, variableRefreshRate, dolbyVision }

class DisplayCapabilities {
  const DisplayCapabilities({
    required this.displayName,
    required this.platform,
    required this.hdr,
    required this.wideColorGamut,
    required this.variableRefreshRate,
    required this.dolbyVision,
    this.details = const <String>[],
  });

  final String displayName;
  final String platform;
  final CapabilityState hdr;
  final CapabilityState wideColorGamut;
  final CapabilityState variableRefreshRate;
  final CapabilityState dolbyVision;
  final List<String> details;

  CapabilityState stateFor(DisplayFeature feature) => switch (feature) {
        DisplayFeature.hdr => hdr,
        DisplayFeature.wideColorGamut => wideColorGamut,
        DisplayFeature.variableRefreshRate => variableRefreshRate,
        DisplayFeature.dolbyVision => dolbyVision,
      };

  /// Safe initial state while native platform adapters are not yet connected.
  factory DisplayCapabilities.unavailable({required String platform}) =>
      DisplayCapabilities(
        displayName: 'Birincil ekran',
        platform: platform,
        hdr: CapabilityState.unknown,
        wideColorGamut: CapabilityState.unknown,
        variableRefreshRate: CapabilityState.unknown,
        dolbyVision: CapabilityState.unknown,
        details: const <String>[
          'Yerel ekran algılama bağlantısı henüz uygulanmadı.',
          'Bu prototip sistem görüntü ayarlarını değiştirmez.',
        ],
      );
}
