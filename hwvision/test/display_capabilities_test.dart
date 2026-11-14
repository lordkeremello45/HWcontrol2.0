import 'package:flutter_test/flutter_test.dart';
import 'package:hwvision/display_capabilities.dart';

void main() {
  group('DisplayCapabilities', () {
    test('unavailable adapter reports unknown rather than supported', () {
      final capabilities =
          DisplayCapabilities.unavailable(platform: 'test-platform');

      expect(capabilities.platform, 'test-platform');
      expect(capabilities.hdr, CapabilityState.unknown);
      expect(capabilities.wideColorGamut, CapabilityState.unknown);
      expect(capabilities.variableRefreshRate, CapabilityState.unknown);
      expect(capabilities.dolbyVision, CapabilityState.unknown);
    });

    test('feature lookup returns the matching capability', () {
      const capabilities = DisplayCapabilities(
        displayName: 'Test display',
        platform: 'test',
        hdr: CapabilityState.supported,
        wideColorGamut: CapabilityState.unsupported,
        variableRefreshRate: CapabilityState.unknown,
        dolbyVision: CapabilityState.unsupported,
      );

      expect(
        capabilities.stateFor(DisplayFeature.hdr),
        CapabilityState.supported,
      );
      expect(
        capabilities.stateFor(DisplayFeature.wideColorGamut),
        CapabilityState.unsupported,
      );
      expect(
        capabilities.stateFor(DisplayFeature.variableRefreshRate),
        CapabilityState.unknown,
      );
      expect(
        capabilities.stateFor(DisplayFeature.dolbyVision),
        CapabilityState.unsupported,
      );
    });
  });
}
