#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <vector>

namespace hwvision::hdr10plus {

struct DistributionMaxRgb {
  std::vector<std::uint8_t> percentages;
  // Linearized maxRGB values in units of 1e-5.
  std::vector<std::uint32_t> percentiles_1e5;
};

struct KneePoint {
  // Normalized values quantized in multiples of 1/4095.
  std::uint16_t x_4095 = 0;
  std::uint16_t y_4095 = 0;
};

struct PeakLuminanceLut {
  std::uint8_t rows = 0;
  std::uint8_t columns = 0;
  // Normalized values in multiples of 1/15.
  std::vector<std::uint8_t> values_15;
};

struct Metadata {
  std::uint8_t application_identifier = 4;
  std::uint8_t application_version = 1;
  std::uint8_t processing_window_count = 1;
  bool window_zero_covers_full_image = true;
  bool contains_nonzero_window = false;

  double targeted_system_display_max_luminance_nits = 0.0;
  std::array<std::uint32_t, 3> max_scl_1e5{};
  std::uint32_t average_max_rgb_1e5 = 0;
  DistributionMaxRgb distribution;
  // FractionBrightPixels in multiples of 0.001 (0..1000).
  std::uint16_t fraction_bright_pixels_1e3 = 0;
  std::optional<KneePoint> knee_point;
  // Intermediate Bezier anchor parameters in multiples of 1/1023.
  std::vector<std::uint16_t> bezier_anchors_1023;

  std::optional<PeakLuminanceLut> targeted_display_peak_luminance_lut;
  std::optional<PeakLuminanceLut> mastering_display_peak_luminance_lut;
  // ColorSaturationWeight in multiples of 1/8 (0..63).
  std::optional<std::uint8_t> color_saturation_weight_eighths;
};

enum class ValidationError : std::uint8_t {
  none,
  invalid_application_identifier,
  unsupported_application_version,
  invalid_processing_window_count,
  window_zero_must_cover_full_image,
  nonzero_window_not_allowed_for_version,
  invalid_target_display_luminance,
  invalid_max_scl,
  invalid_average_max_rgb,
  invalid_distribution_size,
  invalid_distribution_order,
  invalid_distribution_percentile,
  invalid_fraction_bright_pixels,
  invalid_knee_point,
  invalid_bezier_anchor_count,
  invalid_bezier_anchor,
  invalid_peak_luminance_lut,
  invalid_color_saturation_weight,
  forbidden_optional_metadata,
};

struct ValidationResult {
  ValidationError error = ValidationError::none;
  [[nodiscard]] constexpr bool is_valid() const noexcept {
    return error == ValidationError::none;
  }
};

// Validates an already-decoded SMPTE ST 2094-40 Application #4 metadata model.
// This function does not parse T.35/SEI bitstreams.
[[nodiscard]] ValidationResult validate(const Metadata& metadata) noexcept;

enum class OutputMode : std::uint8_t {
  sdr_passthrough,
  hdr10plus_native_passthrough,
  hdr10plus_software_tone_mapping,
  hdr10_static_fallback,
  hdr_to_sdr_tone_mapping,
};

struct OutputCapabilities {
  bool source_is_hdr = false;
  bool hdr10plus_metadata_present = false;
  bool hdr10plus_metadata_valid = false;
  bool hdr_output_supported = false;
  // True only after the complete source -> OS -> driver -> display path is verified.
  bool hdr10plus_native_output_verified = false;
};

// Chooses a safe output route. It does not perform rendering or tone mapping.
[[nodiscard]] OutputMode select_output_mode(const OutputCapabilities& capabilities) noexcept;

}  // namespace hwvision::hdr10plus
