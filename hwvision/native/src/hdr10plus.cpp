#include "hwvision/hdr10plus.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace hwvision::hdr10plus {
namespace {
constexpr std::uint32_t kNormalizedMaximum = 100000U;
constexpr std::size_t kMaximumLutDimension = 25U;

bool valid_lut(const PeakLuminanceLut& lut) noexcept {
  const auto rows = static_cast<std::size_t>(lut.rows);
  const auto columns = static_cast<std::size_t>(lut.columns);
  if (rows < 2U || rows > kMaximumLutDimension ||
      columns < 2U || columns > kMaximumLutDimension) {
    return false;
  }
  const std::size_t expected = rows * columns;
  if (lut.values_15.size() != expected) {
    return false;
  }
  return std::all_of(lut.values_15.begin(), lut.values_15.end(),
                     [](std::uint8_t value) { return value <= 15U; });
}

ValidationResult failure(ValidationError error) noexcept { return {error}; }
}  // namespace

ValidationResult validate(const Metadata& metadata) noexcept {
  if (metadata.application_identifier != 4U) {
    return failure(ValidationError::invalid_application_identifier);
  }
  if (metadata.application_version > 1U) {
    return failure(ValidationError::unsupported_application_version);
  }
  if (metadata.processing_window_count < 1U ||
      metadata.processing_window_count > 3U) {
    return failure(ValidationError::invalid_processing_window_count);
  }
  if (!metadata.window_zero_covers_full_image) {
    return failure(ValidationError::window_zero_must_cover_full_image);
  }
  if (metadata.application_version == 1U &&
      (metadata.processing_window_count != 1U || metadata.contains_nonzero_window)) {
    return failure(ValidationError::nonzero_window_not_allowed_for_version);
  }
  if ((metadata.processing_window_count == 1U && metadata.contains_nonzero_window) ||
      (metadata.processing_window_count > 1U && !metadata.contains_nonzero_window)) {
    return failure(ValidationError::invalid_processing_window_count);
  }
  if (!std::isfinite(metadata.targeted_system_display_max_luminance_nits) ||
      metadata.targeted_system_display_max_luminance_nits <= 0.0 ||
      metadata.targeted_system_display_max_luminance_nits > 10000.0) {
    return failure(ValidationError::invalid_target_display_luminance);
  }
  for (const auto value : metadata.max_scl_1e5) {
    if (value > kNormalizedMaximum) {
      return failure(ValidationError::invalid_max_scl);
    }
  }
  if (metadata.average_max_rgb_1e5 > kNormalizedMaximum) {
    return failure(ValidationError::invalid_average_max_rgb);
  }

  const std::size_t percentage_count = metadata.distribution.percentages.size();
  const std::size_t percentile_count = metadata.distribution.percentiles_1e5.size();
  const std::size_t maximum_count = metadata.application_version == 1U ? 9U : 15U;
  if (percentage_count == 0U || percentage_count != percentile_count ||
      percentage_count > maximum_count ||
      (metadata.application_version == 1U && percentage_count != 9U)) {
    return failure(ValidationError::invalid_distribution_size);
  }
  for (std::size_t index = 0U; index < percentage_count; ++index) {
    if (metadata.distribution.percentages[index] > 100U ||
        (index > 0U && metadata.distribution.percentages[index] <
                           metadata.distribution.percentages[index - 1U])) {
      return failure(ValidationError::invalid_distribution_order);
    }
    if (metadata.distribution.percentiles_1e5[index] > kNormalizedMaximum ||
        (index > 0U && metadata.distribution.percentiles_1e5[index] <
                           metadata.distribution.percentiles_1e5[index - 1U])) {
      return failure(ValidationError::invalid_distribution_percentile);
    }
  }
  if (metadata.fraction_bright_pixels_1e3 > 1000U) {
    return failure(ValidationError::invalid_fraction_bright_pixels);
  }
  if (metadata.knee_point.has_value() &&
      (metadata.knee_point->x_4095 > 4095U ||
       metadata.knee_point->y_4095 > 4095U)) {
    return failure(ValidationError::invalid_knee_point);
  }
  if (!metadata.bezier_anchors_1023.empty() && !metadata.knee_point.has_value()) {
    return failure(ValidationError::invalid_knee_point);
  }
  const std::size_t maximum_anchors = metadata.application_version == 1U ? 9U : 15U;
  if (metadata.bezier_anchors_1023.size() > maximum_anchors) {
    return failure(ValidationError::invalid_bezier_anchor_count);
  }
  for (const auto anchor : metadata.bezier_anchors_1023) {
    if (anchor > 1023U) {
      return failure(ValidationError::invalid_bezier_anchor);
    }
  }

  if ((metadata.targeted_display_peak_luminance_lut.has_value() &&
       !valid_lut(*metadata.targeted_display_peak_luminance_lut)) ||
      (metadata.mastering_display_peak_luminance_lut.has_value() &&
       !valid_lut(*metadata.mastering_display_peak_luminance_lut))) {
    return failure(ValidationError::invalid_peak_luminance_lut);
  }
  if (metadata.color_saturation_weight_eighths.has_value() &&
      *metadata.color_saturation_weight_eighths > 63U) {
    return failure(ValidationError::invalid_color_saturation_weight);
  }
  if (metadata.application_version == 1U &&
      (metadata.targeted_display_peak_luminance_lut.has_value() ||
       metadata.mastering_display_peak_luminance_lut.has_value() ||
       metadata.color_saturation_weight_eighths.has_value())) {
    return failure(ValidationError::forbidden_optional_metadata);
  }
  return {};
}

OutputMode select_output_mode(const OutputCapabilities& capabilities) noexcept {
  if (!capabilities.source_is_hdr) {
    return OutputMode::sdr_passthrough;
  }
  const bool usable_dynamic_metadata = capabilities.hdr10plus_metadata_present &&
                                       capabilities.hdr10plus_metadata_valid;
  if (usable_dynamic_metadata && capabilities.hdr10plus_native_output_verified) {
    return OutputMode::hdr10plus_native_passthrough;
  }
  if (capabilities.hdr_output_supported) {
    return usable_dynamic_metadata ? OutputMode::hdr10plus_software_tone_mapping
                                   : OutputMode::hdr10_static_fallback;
  }
  return OutputMode::hdr_to_sdr_tone_mapping;
}

}  // namespace hwvision::hdr10plus
