/// Deterministic adaptive image-processing policy.
///
/// Selects bounded parameters only; it does not transform pixels or change OS
/// display settings. A future pixel pipeline must consume these parameters.
enum ViewingMode { cinema, gaming, everyday, adaptive }
enum ContentKind { film, game, desktop, unknown }
enum PerformanceBudget { quality, balanced, lowLatency }

class DisplayLimits {
  const DisplayLimits({required this.maxNits, required this.supportsHdr, required this.supportsWideColor, required this.refreshRateHz});
  /// Must come from a trusted platform/display capability adapter.
  final double maxNits;
  final bool supportsHdr;
  final bool supportsWideColor;
  final double refreshRateHz;
}

class VisionInput {
  const VisionInput({required this.mode, required this.content, required this.ambientLux, required this.display, required this.budget, this.userBrightness = 1, this.userColorIntensity = 1});
  final ViewingMode mode;
  final ContentKind content;
  final double ambientLux;
  final DisplayLimits display;
  final PerformanceBudget budget;
  final double userBrightness;
  final double userColorIntensity;
}

class VisionParameters {
  const VisionParameters({required this.mode, required this.targetPeakNits, required this.shadowLift, required this.highlightRollOff, required this.colorIntensity, required this.sharpness, required this.estimatedProcessingCost, required this.hdrPathEnabled, required this.wideColorPathEnabled, required this.explanation});
  final ViewingMode mode;
  final double targetPeakNits;
  final double shadowLift;
  final double highlightRollOff;
  final double colorIntensity;
  final double sharpness;
  /// Relative policy estimate [0,1], not measured GPU utilization.
  final double estimatedProcessingCost;
  final bool hdrPathEnabled;
  final bool wideColorPathEnabled;
  final List<String> explanation;
}

class HwVisionEngine {
  const HwVisionEngine();
  static double _clamp(double value, double min, double max) {
    if (!value.isFinite) return min;
    return value.clamp(min, max).toDouble();
  }

  VisionParameters process(VisionInput input) {
    final mode = switch (input.mode) {
      ViewingMode.adaptive => switch (input.content) {
          ContentKind.film => ViewingMode.cinema,
          ContentKind.game => ViewingMode.gaming,
          ContentKind.desktop || ContentKind.unknown => ViewingMode.everyday,
        },
      _ => input.mode,
    };
    final ambient = _clamp(input.ambientLux, 0, 10000);
    final ambientFactor = ambient < 10 ? 0.90 : ambient < 100 ? 1.0 : ambient < 500 ? 1.10 : 1.20;
    final maxNits = _clamp(input.display.maxNits, 80, 10000);
    final hdr = input.display.supportsHdr;
    final wideColor = input.display.supportsWideColor;

    var peakFactor = switch (mode) {
      ViewingMode.cinema => 0.78, ViewingMode.gaming => 0.95,
      ViewingMode.everyday => 0.72, ViewingMode.adaptive => 0.72,
    };
    var shadowLift = switch (mode) {
      ViewingMode.cinema => 0.025, ViewingMode.gaming => 0.075,
      ViewingMode.everyday => 0.045, ViewingMode.adaptive => 0.045,
    };
    var rollOff = switch (mode) {
      ViewingMode.cinema => 0.82, ViewingMode.gaming => 0.68,
      ViewingMode.everyday => 0.75, ViewingMode.adaptive => 0.75,
    };
    var color = switch (mode) {
      ViewingMode.cinema => 1.0, ViewingMode.gaming => 1.06,
      ViewingMode.everyday => 0.98, ViewingMode.adaptive => 0.98,
    };
    var sharpness = switch (mode) {
      ViewingMode.cinema => 0.12, ViewingMode.gaming => 0.28,
      ViewingMode.everyday => 0.16, ViewingMode.adaptive => 0.16,
    };

    peakFactor *= ambientFactor;
    if (ambient < 10) shadowLift *= 0.6;
    if (ambient >= 500) shadowLift *= 1.15;
    switch (input.budget) {
      case PerformanceBudget.quality:
        break;
      case PerformanceBudget.balanced:
        sharpness *= 0.85;
        break;
      case PerformanceBudget.lowLatency:
        sharpness *= 0.45;
        rollOff = _clamp(rollOff, 0.5, 0.72);
        break;
    }

    final brightness = _clamp(input.userBrightness, 0.5, 1.5);
    final userColor = _clamp(input.userColorIntensity, 0.75, 1.25);
    final targetPeak = _clamp(maxNits * peakFactor * brightness, 80, maxNits);
    final cost = switch (input.budget) {
      PerformanceBudget.quality => 0.80,
      PerformanceBudget.balanced => 0.45,
      PerformanceBudget.lowLatency => 0.20,
    };
    final explanation = <String>[
      'Mod: ${mode.name}',
      hdr ? 'HDR ekran yeteneği doğrulanmış' : 'HDR yolu kapalı: ekran HDR desteği doğrulanmadı',
      wideColor ? 'Geniş renk yolu kullanılabilir' : 'Geniş renk yolu kapalı: destek doğrulanmadı',
      ambient >= 500 ? 'Aydınlık ortam: parlaklık hedefi artırıldı, panel sınırı korunuyor' : ambient < 10 ? 'Karanlık ortam: siyah seviyesini korumak için gölge kaldırma azaltıldı' : 'Ortam ışığı normal aralıkta',
      input.budget == PerformanceBudget.lowLatency ? 'Düşük gecikme bütçesi: işlem karmaşıklığı azaltıldı' : 'İşlem bütçesi: ${input.budget.name}',
      'Renk yoğunluğu güvenli politika aralığında sınırlandı',
    ];
    return VisionParameters(
      mode: mode,
      targetPeakNits: targetPeak,
      shadowLift: _clamp(shadowLift, 0, 0.12),
      highlightRollOff: _clamp(rollOff, 0.4, 1),
      colorIntensity: _clamp(color * userColor, 0.75, 1.2),
      sharpness: _clamp(sharpness, 0, 0.4),
      estimatedProcessingCost: cost,
      hdrPathEnabled: hdr,
      wideColorPathEnabled: wideColor,
      explanation: List.unmodifiable(explanation),
    );
  }
}
