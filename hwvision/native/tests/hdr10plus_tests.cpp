#include "hwvision/hdr10plus.hpp"

#include <cstdlib>
#include <iostream>
#include <limits>

using namespace hwvision::hdr10plus;
namespace {
int failures = 0;
void check(bool ok, int line, const char* expression) {
  if (!ok) {
    std::cerr << "FAIL line " << line << ": " << expression << '\\n';
    ++failures;
  }
}
#define CHECK(x) check((x), __LINE__, #x)

Metadata valid_v1() {
  Metadata metadata;
  metadata.application_identifier = 4;
  metadata.application_version = 1;
  metadata.processing_window_count = 1;
  metadata.window_zero_covers_full_image = true;
  metadata.targeted_system_display_max_luminance_nits = 1000.0;
  metadata.max_scl_1e5 = {100000U, 80000U, 70000U};
  metadata.average_max_rgb_1e5 = 25000U;
  metadata.distribution.percentages = {1, 5, 10, 25, 50, 75, 90, 95, 99};
  metadata.distribution.percentiles_1e5 = {
      1000U, 2000U, 3000U, 8000U, 15000U, 25000U, 40000U, 60000U, 90000U};
  metadata.fraction_bright_pixels_1e3 = 12U;
  metadata.knee_point = KneePoint{2048U, 3072U};
  metadata.bezier_anchors_1023 = {200U, 400U, 600U, 800U};
  return metadata;
}
}  // namespace

int main() {
  auto metadata = valid_v1();
  CHECK(validate(metadata).error == ValidationError::none);
  metadata.application_identifier = 3;
  CHECK(validate(metadata).error == ValidationError::invalid_application_identifier);
  metadata = valid_v1();
  metadata.application_version = 2;
  CHECK(validate(metadata).error == ValidationError::unsupported_application_version);
  metadata = valid_v1();
  metadata.processing_window_count = 0;
  CHECK(validate(metadata).error == ValidationError::invalid_processing_window_count);
  metadata = valid_v1();
  metadata.window_zero_covers_full_image = false;
  CHECK(validate(metadata).error == ValidationError::window_zero_must_cover_full_image);
  metadata = valid_v1();
  metadata.contains_nonzero_window = true;
  CHECK(validate(metadata).error == ValidationError::nonzero_window_not_allowed_for_version);
  metadata = valid_v1();
  metadata.processing_window_count = 2U;
  CHECK(validate(metadata).error == ValidationError::nonzero_window_not_allowed_for_version);
  metadata = valid_v1();
  metadata.targeted_system_display_max_luminance_nits = std::numeric_limits<double>::quiet_NaN();
  CHECK(validate(metadata).error == ValidationError::invalid_target_display_luminance);
  metadata = valid_v1();
  metadata.max_scl_1e5[1] = 100001U;
  CHECK(validate(metadata).error == ValidationError::invalid_max_scl);
  metadata = valid_v1();
  metadata.average_max_rgb_1e5 = 100001U;
  CHECK(validate(metadata).error == ValidationError::invalid_average_max_rgb);
  metadata = valid_v1();
  metadata.distribution.percentages.pop_back();
  CHECK(validate(metadata).error == ValidationError::invalid_distribution_size);
  metadata = valid_v1();
  metadata.distribution.percentages[4] = 2U;
  CHECK(validate(metadata).error == ValidationError::invalid_distribution_order);
  metadata = valid_v1();
  metadata.distribution.percentiles_1e5[5] = 1U;
  CHECK(validate(metadata).error == ValidationError::invalid_distribution_percentile);
  metadata = valid_v1();
  metadata.fraction_bright_pixels_1e3 = 1001U;
  CHECK(validate(metadata).error == ValidationError::invalid_fraction_bright_pixels);
  metadata = valid_v1();
  metadata.bezier_anchors_1023.assign(10U, 10U);
  CHECK(validate(metadata).error == ValidationError::invalid_bezier_anchor_count);
  metadata = valid_v1();
  metadata.knee_point = KneePoint{4096U, 0U};
  CHECK(validate(metadata).error == ValidationError::invalid_knee_point);
  metadata = valid_v1();
  metadata.targeted_display_peak_luminance_lut =
      PeakLuminanceLut{2U, 2U, {0U, 5U, 10U, 15U}};
  CHECK(validate(metadata).error == ValidationError::forbidden_optional_metadata);
  metadata = valid_v1();
  metadata.application_version = 0;
  metadata.distribution.percentages.resize(16U);
  metadata.distribution.percentiles_1e5.resize(16U);
  CHECK(validate(metadata).error == ValidationError::invalid_distribution_size);
  metadata = valid_v1();
  metadata.application_version = 0;
  metadata.bezier_anchors_1023.assign(16U, 10U);
  CHECK(validate(metadata).error == ValidationError::invalid_bezier_anchor_count);
  metadata = valid_v1();
  metadata.application_version = 0;
  metadata.targeted_display_peak_luminance_lut =
      PeakLuminanceLut{2U, 2U, {0U, 5U, 10U, 15U}};
  CHECK(validate(metadata).error == ValidationError::none);
  metadata = valid_v1();
  metadata.application_version = 0;
  metadata.processing_window_count = 2U;
  metadata.contains_nonzero_window = true;
  CHECK(validate(metadata).error == ValidationError::none);
  metadata = valid_v1();
  metadata.targeted_display_peak_luminance_lut = PeakLuminanceLut{1U, 2U, {0U, 1U}};
  CHECK(validate(metadata).error == ValidationError::invalid_peak_luminance_lut);
  metadata = valid_v1();
  metadata.color_saturation_weight_eighths = 64U;
  CHECK(validate(metadata).error == ValidationError::invalid_color_saturation_weight);
  metadata = valid_v1();
  metadata.bezier_anchors_1023 = {1024U};
  CHECK(validate(metadata).error == ValidationError::invalid_bezier_anchor);

  OutputCapabilities capabilities;
  capabilities.source_is_hdr = true;
  capabilities.hdr10plus_metadata_present = true;
  capabilities.hdr10plus_metadata_valid = true;
  capabilities.hdr_output_supported = true;
  capabilities.hdr10plus_native_output_verified = true;
  CHECK(select_output_mode(capabilities) == OutputMode::hdr10plus_native_passthrough);
  capabilities.hdr10plus_native_output_verified = false;
  CHECK(select_output_mode(capabilities) == OutputMode::hdr10plus_software_tone_mapping);
  capabilities.hdr10plus_metadata_valid = false;
  CHECK(select_output_mode(capabilities) == OutputMode::hdr10_static_fallback);
  capabilities.hdr_output_supported = false;
  CHECK(select_output_mode(capabilities) == OutputMode::hdr_to_sdr_tone_mapping);
  capabilities.source_is_hdr = false;
  CHECK(select_output_mode(capabilities) == OutputMode::sdr_passthrough);

  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
