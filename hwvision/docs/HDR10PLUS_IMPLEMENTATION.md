# HWVision HDR10+ Implementation Status

**Decision:** HDR10+ (SMPTE ST 2094-40, Application #4) is the primary dynamic-HDR format targeted by HWVision. HDR10 remains the static-HDR fallback; SDR remains the baseline path.

**Status as of 2026-11-15:** PARTIAL — C++17 metadata model/validator and deterministic output-route policy are implemented. Bitstream extraction, decoding, pixel processing, native display integration and hardware certification are not implemented.

## Implemented in this change

- Typed C++ metadata model for ApplicationIdentifier 4 and ApplicationVersion 0/1.
- Semantic validation of processing-window count and constraints, target display luminance, MaxSCL, AverageMaxRGB, DistributionMaxRGB, FractionBrightPixels, KneePoint, Bezier anchors, optional peak-luminance LUTs and ColorSaturationWeight.
- Version-specific bounds for DistributionMaxRGB and BezierCurveAnchors.
- Version 1 rejection of optional metadata prohibited by ST 2094-40:2020.
- Deterministic output-route selection:
  - Verified native HDR10+ passthrough only when the complete output chain has been explicitly verified.
  - Software HDR10+ metadata-driven tone-mapping route when valid metadata exists and HDR output is available.
  - HDR10 static fallback when dynamic metadata is absent or invalid.
  - HDR-to-SDR tone-mapping route when HDR output is unavailable.
  - SDR passthrough for SDR sources.
- Flutter display capability model now distinguishes HDR10+ metadata support, native passthrough, HDR10+ ADVANCED and HDR10+ GAMING. All remain unknown until native adapters provide evidence.

## Explicitly not implemented

- T.35 / SEI / container-level HDR10+ payload extraction or binary parser.
- Video decoder integration or per-frame metadata delivery.
- ST 2094-40 tone-mapping renderer, color-space conversion, PQ decode/encode, gamut mapping or dithering.
- DXGI/D3D12, Vulkan/DRM or Metal/EDR native presentation adapters.
- Verified native HDR10+ passthrough on any OS/GPU/display combination.
- HDR10+ ADVANCED and HDR10+ GAMING runtime support.
- Adopter application, certification, logo use or legal clearance.

The C++ validator accepts an **already-decoded semantic metadata model**. It must not be described as a complete HDR10+ parser or a playback implementation. It does not currently validate every bitstream syntax rule or prove conformance certification. The next parser must consume a codec/container adapter contract, bound payload size before parsing, reject malformed T.35/SEI data, and preserve version/profile information.

## Standard constraints represented

The model follows the public SMPTE ST 2094-40:2020 Application #4 model:
- ApplicationIdentifier = 4.
- ApplicationVersion = 0 or 1.
- Processing window count is bounded to 1..3; window 0 covers the complete image.
- Version 1 permits only window 0.
- MaxSCL and AverageMaxRGB are normalized to [0,1] at 1e-5 precision.
- DistributionMaxRGB percentage and percentile vectors have equal lengths; version 0 is bounded to 15 entries, version 1 requires 9.
- FractionBrightPixels is normalized to [0,1] in 0.001 increments.
- KneePoint uses 1/4095 increments; Bezier anchors use 1/1023 increments and are bounded to 15 entries for version 0 and 9 for version 1.
- Optional TargetedSystemDisplayActualPeakLuminance, MasteringDisplayActualPeakLuminance and ColorSaturationWeight are rejected for version 1.

The version 1 DistributionMaxRGB J-vector values in the standard are recommended ("should"), so this validator checks ordering and count but does not incorrectly upgrade that recommendation into a mandatory rejection. The current validator also does not yet evaluate the full Bezier derivative monotonicity constraint; the renderer/conformance stage must add that before claiming conformance.

## Output policy safety

Native passthrough is not inferred from generic HDR support, an EDID flag, or the existence of an OS enum. The hdr10plus_native_output_verified input must be set only after the exact source → application → OS compositor/presentation API → GPU driver → display chain has been validated.

Microsoft documents an HDR10+ metadata enum in DisplayWireFormatHdrMetadata, but that enum alone does not prove a specific application's swapchain can deliver ST 2094-40 metadata. DXGI SetHDRMetaData accepts the HDR10 static metadata structure and Microsoft warns applications not to rely on monitor metadata passthrough. HWVision must therefore prefer its own measured tone-mapping output unless a native dynamic-metadata route is explicitly verified.

## Licensing and marks

HDR10+ Technologies' official license page lists Tool Vendor (including processing tools and game engines) with self-testing and N/A annual administration. This is not a substitute for a signed adopter agreement or written confirmation of the applicable terms. HWVision must not use certification marks or claim certification until adopter status, test obligations, trademark permissions and applicable IP terms are confirmed.

## Verification

Native tests cover valid version 1 metadata, version bounds, malformed ranges, distribution lengths/order, Bezier limits, optional metadata restrictions, version 0 optional metadata, and output fallback selection. These are unit tests for the semantic model, not official HDR10+ certification vectors.

Run:

    cmake -S hwvision/native -B build/hwvision -DBUILD_TESTING=ON
    cmake --build build/hwvision --config Release --parallel 2
    ctest --test-dir build/hwvision -C Release --output-on-failure

Flutter verification:

    cd hwvision
    flutter pub get
    flutter analyze --fatal-infos
    flutter test

## Next implementation gates

1. Add a codec-independent bounded T.35/SEI parser contract and test corpus.
2. Add a licensed/compatible FFmpeg or other decoder adapter only after dependency and distribution-license review.
3. Implement PQ/BT.2020 reference color math and ST 2094-40 tone mapping with deterministic vectors.
4. Add Windows, Linux and macOS display capability adapters behind injectable interfaces.
5. Integrate renderers and measure frame-time, color error, highlight clipping and shadow preservation.
6. Validate on physical HDR displays and verify exact output paths; keep untested platforms UNVERIFIED.
7. Confirm HDR10+ adopter/legal terms before trademark use or public certification claims.

## Official references

- SMPTE ST 2094-40:2020 — https://pub.smpte.org/pub/st2094-40/st2094-40-2020.pdf
- HDR10+ official license programs and pricing — https://hdr10plus.org/
- HDR10+ official FAQ — https://hdr10plus.org/hdr10_faq/is-hdr10-an-open-royalty-free-standard/
- Microsoft DisplayWireFormatHdrMetadata — https://learn.microsoft.com/en-us/uwp/api/windows.devices.display.core.displaywireformathdrmetadata
- Microsoft IDXGISwapChain4::SetHDRMetaData — https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_5/nf-dxgi1_5-idxgiswapchain4-sethdrmetadata
- FFmpeg AVDynamicHDRPlus data model — https://ffmpeg.org/doxygen/trunk/hdr__dynamic__metadata_8h_source.html
