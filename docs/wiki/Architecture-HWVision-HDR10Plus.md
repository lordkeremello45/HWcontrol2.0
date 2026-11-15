# Architecture: HWVision HDR10+

**Status:** PARTIAL. The first C++17 HDR10+ semantic metadata and output-policy slice is implemented. Bitstream parsing, pixel processing, native display adapters and physical hardware validation are NOT IMPLEMENTED.

## Product decision

HWVision targets HDR10+ (SMPTE ST 2094-40 Application #4) as its primary dynamic-HDR format. HDR10 remains the static HDR fallback; SDR remains the baseline. Dolby Vision is not a dependency and is not claimed as supported.

## Current implementation

The native HWVision library now includes:
- A typed metadata model for ApplicationIdentifier 4 and ApplicationVersion 0/1.
- Semantic validation for processing windows, target luminance, MaxSCL, AverageMaxRGB, DistributionMaxRGB, FractionBrightPixels, KneePoint, Bezier anchors and version-dependent optional metadata.
- A deterministic output-route selector. It permits native HDR10+ passthrough only when an explicit capability flag says the complete source-to-display path was verified; otherwise it chooses software tone mapping or HDR10/SDR fallback.

The Flutter capability model distinguishes:
- HDR10+ metadata support.
- Native HDR10+ passthrough.
- HDR10+ ADVANCED.
- HDR10+ GAMING.

All four remain unknown until platform adapters supply real evidence.

## Pipeline target

    Video/container source
      -> codec/container adapter
      -> bounded T.35 / SEI extraction
      -> ST 2094-40 metadata parser
      -> semantic validator
      -> source transfer function / primaries identification
      -> target display capability snapshot
      -> HDR10+ scene-adaptive tone mapping
      -> DX12 / Vulkan / Metal render backend
      -> measured output and diagnostics

The Go Bridge remains the authenticated control/telemetry plane. Frame data must not be sent through JSON IPC.

## Critical limitations

- The current C++ validator accepts an already-decoded semantic model; it is not a binary T.35/SEI parser.
- No video decoder is connected.
- No PQ/BT.2020 pixel transform or ST 2094-40 renderer exists yet.
- No OS display API adapter exists.
- Native HDR10+ passthrough is not verified on Windows, Linux or macOS.
- HDR10+ ADVANCED and GAMING are separate profiles and are not implied by base HDR10+ metadata support.
- Certification marks and logos must not be used until the adopter agreement, testing and trademark permissions are confirmed.

## Platform notes

Windows exposes an HDR10+ metadata enum in DisplayWireFormatHdrMetadata, but this alone does not prove that a given app/driver/display chain can transport ST 2094-40 dynamic metadata. DXGI SetHDRMetaData takes the HDR10 static metadata structure and Microsoft warns not to rely on monitor metadata passthrough. The renderer must therefore support software tone mapping and only claim passthrough after device-level verification.

Linux HDR output depends on compositor, DRM/KMS, driver and display chain. A static HDR output metadata property is not proof of dynamic ST 2094-40 transport.

macOS Metal/EDR provides an HDR-capable rendering path, but EDR availability is not proof of native HDR10+ metadata passthrough.

## Security and quality gates

- Treat all container and metadata payloads as untrusted.
- Bound payload size, windows, LUT dimensions and vector lengths before allocation or iteration.
- Reject unknown versions and invalid metadata; do not silently reinterpret.
- Preserve HDR10 and SDR fallback paths.
- Keep native display inspection read-only; display mutations require explicit user action and rollback.
- Add parser fuzzing, sanitizer runs, deterministic color vectors, reference images and measured frame-time tests.
- Do not claim conformance or certification based only on unit tests.

## Licensing

The official HDR10+ license page lists Tool Vendor (processing tools and game engines) with self-test certification requirements and N/A annual administration. This does not replace a signed adopter agreement or written confirmation of eligibility, IP terms and trademark permissions. Do not use the HDR10+ certification mark until these are confirmed.

## Sources

- SMPTE ST 2094-40:2020: https://pub.smpte.org/pub/st2094-40/st2094-40-2020.pdf
- HDR10+ licensing: https://hdr10plus.org/
- Microsoft DisplayWireFormatHdrMetadata: https://learn.microsoft.com/en-us/uwp/api/windows.devices.display.core.displaywireformathdrmetadata
- Microsoft IDXGISwapChain4::SetHDRMetaData: https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_5/nf-dxgi1_5-idxgiswapchain4-sethdrmetadata
- FFmpeg AVDynamicHDRPlus model: https://ffmpeg.org/doxygen/trunk/hdr__dynamic__metadata_8h_source.html

See also: [HWVision HDR10+ implementation status](../../hwvision/docs/HDR10PLUS_IMPLEMENTATION.md).
