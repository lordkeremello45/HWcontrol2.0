/// Display capability model shared by platform-specific adapters and UI.
///
/// Unknown is intentionally distinct from unsupported: an unimplemented or
/// failed native adapter must never make the UI claim a capability exists.
enum CapabilityState { supported, unsupported, unknown }

enum DisplayFeature {
  hdr,
  hdr10PlusMetadata,
  hdr10PlusPassthrough,
  hdr10PlusAdvanced,
  hdr10PlusGaming,
  wideColorGamut,
  variableRefreshRate,
  dolbyVision,
}

class DisplayCapabilities {
  const DisplayCapabilities({
    required this.displayName,
    required this.platform,
    required this.hdr,
    required this.wideColorGamut,
    required this.variableRefreshRate,
    required this.dolbyVision,
    this.hdr10PlusMetadata = CapabilityState.unknown,
    this.hdr10PlusPassthrough = CapabilityState.unknown,
    this.hdr10PlusAdvanced = CapabilityState.unknown,
    this.hdr10PlusGaming = CapabilityState.unknown,
    this.details = const <String>[],
  });

  final String displayName;
  final String platform;
  final CapabilityState hdr;
  final CapabilityState hdr10PlusMetadata;
  final CapabilityState hdr10PlusPassthrough;
  final CapabilityState hdr10PlusAdvanced;
  final CapabilityState hdr10PlusGaming;
  final CapabilityState wideColorGamut;
  final CapabilityState variableRefreshRate;
  final CapabilityState dolbyVision;
  final List<String> details;

  CapabilityState stateFor(DisplayFeature feature) => switch (feature) {
        DisplayFeature.hdr => hdr,
        DisplayFeature.hdr10PlusMetadata => hdr10PlusMetadata,
        DisplayFeature.hdr10PlusPassthrough => hdr10PlusPassthrough,
        DisplayFeature.hdr10PlusAdvanced => hdr10PlusAdvanced,
        DisplayFeature.hdr10PlusGaming => hdr10PlusGaming,
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
        hdr10PlusMetadata: CapabilityState.unknown,
        hdr10PlusPassthrough: CapabilityState.unknown,
        hdr10PlusAdvanced: CapabilityState.unknown,
        hdr10PlusGaming: CapabilityState.unknown,
        wideColorGamut: CapabilityState.unknown,
        variableRefreshRate: CapabilityState.unknown,
        dolbyVision: CapabilityState.unknown,
        details: const <String>[
          'Yerel ekran algılama bağlantısı henüz uygulanmadı.',
          'HDR10+ metadata ve ekran passthrough desteği henüz doğrulanmadı.',
          'Bu prototip sistem görüntü ayarlarını değiştirmez.',
        ],
      );
}
