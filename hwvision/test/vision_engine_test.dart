import 'package:flutter_test/flutter_test.dart';
import 'package:hwvision/vision_engine.dart';

void main() {
  const engine = HwVisionEngine();
  VisionInput input({
    ViewingMode mode = ViewingMode.adaptive,
    ContentKind content = ContentKind.film,
    double lux = 50,
    double maxNits = 1000,
    bool hdr = true,
    bool wideColor = true,
    PerformanceBudget budget = PerformanceBudget.balanced,
    double brightness = 1,
    double color = 1,
  }) => VisionInput(
    mode: mode, content: content, ambientLux: lux,
    display: DisplayLimits(maxNits: maxNits, supportsHdr: hdr, supportsWideColor: wideColor, refreshRateHz: 144),
    budget: budget, userBrightness: brightness, userColorIntensity: color,
  );

  test('adaptive mode follows content type', () {
    expect(engine.process(input(content: ContentKind.film)).mode, ViewingMode.cinema);
    expect(engine.process(input(content: ContentKind.game)).mode, ViewingMode.gaming);
    expect(engine.process(input(content: ContentKind.desktop)).mode, ViewingMode.everyday);
  });
  test('does not enable HDR or wide color without reported support', () {
    final result = engine.process(input(hdr: false, wideColor: false));
    expect(result.hdrPathEnabled, isFalse);
    expect(result.wideColorPathEnabled, isFalse);
    expect(result.explanation.join(' '), contains('HDR yolu kapalı'));
  });
  test('target peak never exceeds reported panel capability', () {
    for (final lux in <double>[-100, 0, 10, 100, 500, 10000, 1e9]) {
      final result = engine.process(input(lux: lux, maxNits: 400, brightness: 99));
      expect(result.targetPeakNits, lessThanOrEqualTo(400));
      expect(result.targetPeakNits, greaterThanOrEqualTo(80));
    }
  });
  test('all processing controls remain bounded for extreme input', () {
    final result = engine.process(input(lux: double.nan, maxNits: double.infinity, brightness: double.infinity, color: -999));
    expect(result.shadowLift, inInclusiveRange(0, 0.12));
    expect(result.highlightRollOff, inInclusiveRange(0.4, 1));
    expect(result.colorIntensity, inInclusiveRange(0.75, 1.2));
    expect(result.sharpness, inInclusiveRange(0, 0.4));
    expect(result.targetPeakNits.isFinite, isTrue);
  });
  test('low latency budget reduces policy complexity', () {
    final quality = engine.process(input(budget: PerformanceBudget.quality));
    final low = engine.process(input(budget: PerformanceBudget.lowLatency));
    expect(low.estimatedProcessingCost, lessThan(quality.estimatedProcessingCost));
    expect(low.sharpness, lessThan(quality.sharpness));
  });
  test('ambient light adapts peak target and shadow lift', () {
    final dark = engine.process(input(lux: 0));
    final bright = engine.process(input(lux: 1000));
    expect(bright.targetPeakNits, greaterThan(dark.targetPeakNits));
    expect(dark.shadowLift, lessThan(bright.shadowLift));
  });
}
