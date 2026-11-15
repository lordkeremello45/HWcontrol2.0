#include "hwvision/ffmpeg_hdr10plus.hpp"
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <utility>
#if defined(HWVISION_HAS_FFMPEG)
extern "C" {
#include <libavutil/hdr_dynamic_metadata.h>
}
#endif
namespace hwvision::hdr10plus::ffmpeg {
namespace {
ExtractionResult fail(ExtractionError error) noexcept { return {error}; }
#if defined(HWVISION_HAS_FFMPEG)
bool scaled(AVRational q, std::uint32_t scale, std::uint32_t max,
            std::uint32_t& out) noexcept {
  if (q.den <= 0 || q.num < 0) return false;
  const auto n = static_cast<std::uint64_t>(q.num) * scale;
  const auto d = static_cast<std::uint64_t>(q.den);
  const auto value = (n + d / 2U) / d;
  if (value > max) return false;
  out = static_cast<std::uint32_t>(value);
  return true;
}
bool convert(const AVDynamicHDRPlus& s, Metadata& out) {
  if (s.itu_t_t35_country_code != 0xB5U || s.application_version > 1U ||
      s.num_windows < 1U || s.num_windows > 3U ||
      s.targeted_system_display_actual_peak_luminance_flag > 1U ||
      s.mastering_display_actual_peak_luminance_flag > 1U) return false;
  const auto& p = s.params[0];
  if (p.color_saturation_mapping_flag != 0U || p.num_distribution_maxrgb_percentiles > 15U ||
      p.tone_mapping_flag > 1U) return false;
  Metadata m;
  m.application_identifier = 4U;
  m.application_version = s.application_version;
  m.processing_window_count = s.num_windows;
  m.window_zero_covers_full_image = true;
  m.contains_nonzero_window = s.num_windows > 1U;
  m.targeted_system_display_max_luminance_nits = av_q2d(s.targeted_system_display_maximum_luminance);
  if (!std::isfinite(m.targeted_system_display_max_luminance_nits)) return false;
  for (std::size_t i=0; i<3; ++i)
    if (!scaled(p.maxscl[i],100000U,100000U,m.max_scl_1e5[i])) return false;
  if (!scaled(p.average_maxrgb,100000U,100000U,m.average_max_rgb_1e5)) return false;
  for (std::size_t i=0; i<p.num_distribution_maxrgb_percentiles; ++i) {
    std::uint32_t v=0;
    if (!scaled(p.distribution_maxrgb[i].percentile,100000U,100000U,v)) return false;
    m.distribution.percentages.push_back(p.distribution_maxrgb[i].percentage);
    m.distribution.percentiles_1e5.push_back(v);
  }
  std::uint32_t fraction=0;
  if (!scaled(p.fraction_bright_pixels,1000U,1000U,fraction)) return false;
  m.fraction_bright_pixels_1e3=static_cast<std::uint16_t>(fraction);
  if (p.tone_mapping_flag != 0U) {
    std::uint32_t x=0,y=0;
    if (!scaled(p.knee_point_x,4095U,4095U,x) ||
        !scaled(p.knee_point_y,4095U,4095U,y) ||
        p.num_bezier_curve_anchors > 15U) return false;
    m.knee_point=KneePoint{static_cast<std::uint16_t>(x),static_cast<std::uint16_t>(y)};
    for (std::size_t i=0; i<p.num_bezier_curve_anchors; ++i) {
      std::uint32_t a=0;
      if (!scaled(p.bezier_curve_anchors[i],1023U,1023U,a)) return false;
      m.bezier_anchors_1023.push_back(static_cast<std::uint16_t>(a));
    }
  } else if (p.num_bezier_curve_anchors != 0U) return false;
  if (s.targeted_system_display_actual_peak_luminance_flag != 0U ||
      s.mastering_display_actual_peak_luminance_flag != 0U) return false;
  std::uint32_t saturation=0;
  if (!scaled(p.color_saturation_weight,8U,63U,saturation)) return false;
  if (saturation != 8U) m.color_saturation_weight_eighths=static_cast<std::uint8_t>(saturation);
  if (!validate(m).is_valid()) return false;
  out=std::move(m);
  return true;
}
#endif
}
ExtractionResult extract_frame_metadata(
#if defined(HWVISION_HAS_FFMPEG)
    const AVFrame& frame,
#else
    const void* frame,
#endif
    Metadata& output) noexcept {
#if defined(HWVISION_HAS_FFMPEG)
  const auto* side=av_frame_get_side_data(&frame,AV_FRAME_DATA_DYNAMIC_HDR_PLUS);
  if (!side) return fail(ExtractionError::frame_has_no_dynamic_metadata);
  if (!side->data || side->size < sizeof(AVDynamicHDRPlus)) return fail(ExtractionError::invalid_side_data);
  const auto* metadata=reinterpret_cast<const AVDynamicHDRPlus*>(side->data);
  if (metadata->itu_t_t35_country_code != 0xB5U) return fail(ExtractionError::unsupported_country_code);
  if (metadata->application_version > 1U) return fail(ExtractionError::unsupported_application_version);
  try {
    Metadata candidate;
    if (!convert(*metadata,candidate)) return fail(ExtractionError::invalid_metadata);
    output=std::move(candidate);
    return {};
  } catch (...) {
    return fail(ExtractionError::invalid_metadata);
  }
#else
  (void)frame; (void)output;
  return fail(ExtractionError::ffmpeg_not_enabled);
#endif
}
}  // namespace hwvision::hdr10plus::ffmpeg
